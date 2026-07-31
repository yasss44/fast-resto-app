import { Request, Response } from 'express';
import Stripe from 'stripe';
import { env } from '../config/env';
import { prisma } from '../services/prisma';
import { placeOrderSchema } from '../utils/validation';
import { computeCartPricing } from '../utils/cartPricing';
import { generatePickupToken } from '../utils/pickupToken';
import {
  distanceKm,
  driverGainFromDeliveryFee,
  formatDistanceKm,
} from '../utils/deliveryHelpers';
import {
  safeEmitNotificationToUser,
  safeEmitOrderToRestaurant,
} from '../services/realtime';

function stripeClient(): Stripe {
  if (!env.stripeSecretKey) {
    throw new Error('Stripe is not configured. Set STRIPE_SECRET_KEY.');
  }
  return new Stripe(env.stripeSecretKey);
}

function cents(amount: number): number {
  return Math.round(amount * 100);
}

async function createPaidOrderFromCheckout(
  checkoutId: string,
  stripePaymentIntentId?: string | null,
) {
  for (let attempt = 0; attempt < 3; attempt++) {
    try {
      const result = await prisma.$transaction(async (tx) => {
        const checkout = await tx.paymentCheckout.findUnique({
          where: { id: checkoutId },
        });
        if (!checkout) throw new Error('Payment checkout not found');

        if (checkout.createdOrderId) {
          const order = await tx.order.findUnique({
            where: { id: checkout.createdOrderId },
            include: {
              items: { include: { menuItem: true } },
              restaurant: true,
              groupOrder: { select: { code: true, status: true } },
            },
          });
          return { order, created: false };
        }

        const restaurant = await tx.restaurant.findUnique({ where: { id: checkout.restaurantId } });
        if (!restaurant) throw new Error('Restaurant not found');

        const items = JSON.parse(checkout.itemsJson) as Array<{
          menuItemId: string;
          quantity: number;
          selectedOptions?: string[];
          allergyNotes?: string;
        }>;

        if (checkout.groupOrderId) {
          const member = await tx.groupMember.findUnique({
            where: {
              groupId_userId: {
                groupId: checkout.groupOrderId,
                userId: checkout.userId,
              },
            },
            include: { group: { select: { status: true, restaurantId: true } } },
          });
          if (!member || member.group.restaurantId !== checkout.restaurantId) {
            throw new Error('Invalid group checkout');
          }
          if (!['OPEN', 'LOCKED'].includes(member.group.status)) {
            throw new Error('Group no longer accepts payments');
          }
        }

        const order = await tx.order.create({
          data: {
            restaurantId: checkout.restaurantId,
            userId: checkout.userId,
            subtotal: checkout.subtotal,
            serviceFee: checkout.serviceFee,
            deliveryFee: checkout.deliveryFee,
            total: checkout.total,
            fulfillmentType: checkout.fulfillmentType,
            deliveryAddress: checkout.deliveryAddress,
            deliveryLatitude: checkout.deliveryLatitude,
            deliveryLongitude: checkout.deliveryLongitude,
            userWalkTimeMin: checkout.userWalkTimeMin,
            paymentStatus: 'PAID',
            stripeCheckoutSessionId: checkout.stripeCheckoutSessionId,
            stripePaymentIntentId: stripePaymentIntentId ?? null,
            pickupToken: checkout.fulfillmentType === 'PICKUP' ? generatePickupToken() : null,
            stripeApplicationFeeAmount: cents(checkout.serviceFee),
            stripeRestaurantAmount: cents(checkout.subtotal),
            paidAt: new Date(),
            groupOrderId: checkout.groupOrderId,
            items: {
              create: items.map((item) => ({
                menuItemId: item.menuItemId,
                quantity: item.quantity,
                selectedOptions: JSON.stringify(item.selectedOptions || []),
                allergyNotes: (item.allergyNotes || '').slice(0, 500),
              })),
            },
          },
          include: {
            items: { include: { menuItem: true } },
            restaurant: true,
            groupOrder: { select: { code: true, status: true } },
          },
        });

        if (checkout.fulfillmentType === 'DELIVERY') {
          let distLabel = '—';
          if (
            checkout.deliveryLatitude != null &&
            checkout.deliveryLongitude != null
          ) {
            const km = distanceKm(
              restaurant.latitude,
              restaurant.longitude,
              checkout.deliveryLatitude,
              checkout.deliveryLongitude,
            );
            distLabel = formatDistanceKm(km);
          }
          await tx.delivery.create({
            data: {
              orderId: order.id,
              restaurantId: restaurant.id,
              restaurantName: restaurant.name,
              destination: checkout.deliveryAddress,
              distance: distLabel,
              gain: driverGainFromDeliveryFee(checkout.deliveryFee),
              status: 'AVAILABLE',
            },
          });
        }

        await tx.paymentCheckout.update({
          where: { id: checkout.id },
          data: { createdOrderId: order.id },
        });

        if (checkout.groupOrderId) {
          await tx.groupMember.update({
            where: {
              groupId_userId: {
                groupId: checkout.groupOrderId,
                userId: checkout.userId,
              },
            },
            data: {
              itemsCount: items.reduce((sum, item) => sum + item.quantity, 0),
              total: checkout.total,
              isReady: true,
              paymentStatus: 'PAID',
            },
          });
        }

        return { order, created: true, restaurantOwnerId: restaurant.ownerId };
      }, { isolationLevel: 'Serializable' });

      if (!result.order) throw new Error('Paid order not found');

      if (result.created && !result.order.groupOrderId) {
        const notification = await prisma.notification.create({
          data: {
            userId: result.restaurantOwnerId!,
            orderId: result.order.id,
            title: 'Nouvelle commande payée !',
            body: `Commande #${result.order.id.slice(-6)} — ${result.order.items.length} article(s)`,
            type: 'STATUS',
          },
        });
        safeEmitOrderToRestaurant(result.order.restaurantId, result.order);
        safeEmitNotificationToUser(result.restaurantOwnerId!, notification);
      }

      return result.order;
    } catch (error) {
      if ((error as { code?: string }).code === 'P2034' && attempt < 2) {
        continue;
      }
      throw error;
    }
  }
  throw new Error('Could not create paid order');
}

export const createCheckoutSession = async (req: Request, res: Response): Promise<void> => {
  try {
    const stripe = stripeClient();
    const data = placeOrderSchema.parse(req.body);

    const restaurant = await prisma.restaurant.findUnique({ where: { id: data.restaurantId } });
    if (!restaurant || !restaurant.isActive) {
      res.status(404).json({ error: 'Restaurant introuvable ou inactif' });
      return;
    }

    let groupOrderResponse: { code: string; status: string } | null = null;
    if (data.groupId) {
      const member = await prisma.groupMember.findUnique({
        where: {
          groupId_userId: {
            groupId: data.groupId,
            userId: req.user!.userId,
          },
        },
        include: {
          group: { select: { code: true, status: true, restaurantId: true } },
        },
      });
      if (!member) {
        res.status(403).json({ error: 'Vous n’êtes pas membre de ce groupe' });
        return;
      }
      if (!['OPEN', 'LOCKED'].includes(member.group.status)) {
        res.status(409).json({ error: 'Ce groupe n’accepte plus de paiements' });
        return;
      }
      if (member.group.restaurantId !== data.restaurantId) {
        res.status(400).json({ error: 'Le restaurant ne correspond pas au groupe' });
        return;
      }
      const paidCheckout = await prisma.paymentCheckout.findFirst({
        where: {
          groupOrderId: data.groupId,
          userId: req.user!.userId,
          createdOrderId: { not: null },
        },
        select: { id: true },
      });
      if (member.paymentStatus === 'PAID' || paidCheckout) {
        res.status(409).json({ error: 'Votre part de ce groupe est déjà payée' });
        return;
      }
      groupOrderResponse = {
        code: member.group.code,
        status: member.group.status,
      };
    }

    let pricing;
    try {
      pricing = await computeCartPricing(data.restaurantId, data.items);
    } catch (err) {
      const message = (err as Error).message;
      if (message === 'MENU_ITEMS_NOT_FOUND') {
        res.status(400).json({ error: 'Certains articles du menu sont introuvables' });
        return;
      }
      if (message === 'MENU_ITEMS_UNAVAILABLE') {
        res.status(400).json({ error: 'Certains articles ne sont plus disponibles' });
        return;
      }
      if (message === 'SUPPLEMENT_NOT_FOUND') {
        res.status(400).json({ error: 'Un supplément sélectionné est introuvable' });
        return;
      }
      throw err;
    }

    const serviceFee = env.serviceFee;
    const fulfillmentType = data.fulfillmentType ?? 'PICKUP';
    let deliveryFee = 0;

    if (fulfillmentType === 'DELIVERY') {
      if (!restaurant.deliveryEnabled) {
        res.status(400).json({ error: 'Ce restaurant ne propose pas la livraison' });
        return;
      }
      if (
        data.deliveryLatitude != null &&
        data.deliveryLongitude != null
      ) {
        const km = distanceKm(
          restaurant.latitude,
          restaurant.longitude,
          data.deliveryLatitude,
          data.deliveryLongitude,
        );
        if (km > restaurant.deliveryRadiusKm) {
          res.status(400).json({
            error: `Adresse hors zone de livraison (${restaurant.deliveryRadiusKm} km max)`,
          });
          return;
        }
      }
      deliveryFee = restaurant.deliveryFee;
    }

    const total = Math.round((pricing.subtotal + serviceFee + deliveryFee) * 100) / 100;

    const checkout = await prisma.paymentCheckout.create({
      data: {
        userId: req.user!.userId,
        restaurantId: data.restaurantId,
        itemsJson: JSON.stringify(data.items),
        userWalkTimeMin: data.userWalkTimeMin,
        fulfillmentType,
        deliveryAddress: data.deliveryAddress?.trim() ?? '',
        deliveryLatitude: data.deliveryLatitude,
        deliveryLongitude: data.deliveryLongitude,
        deliveryFee,
        subtotal: pricing.subtotal,
        serviceFee,
        total,
        groupOrderId: data.groupId,
      },
    });

    const paymentIntentData: Stripe.Checkout.SessionCreateParams.PaymentIntentData = {};
    if (restaurant.stripeAccountId && restaurant.stripeChargesEnabled) {
      paymentIntentData.application_fee_amount = cents(serviceFee);
      paymentIntentData.transfer_data = { destination: restaurant.stripeAccountId };
    }

    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      currency: env.stripeCurrency,
      customer_email: undefined,
      client_reference_id: checkout.id,
      metadata: {
        checkoutId: checkout.id,
        userId: req.user!.userId,
        restaurantId: data.restaurantId,
        ...(data.groupId ? { groupId: data.groupId } : {}),
      },
      line_items: [
        ...pricing.items.map((item) => ({
          quantity: item.quantity,
          price_data: {
            currency: env.stripeCurrency,
            unit_amount: cents(item.unitPrice),
            product_data: { name: item.menuItemName },
          },
        })),
        {
          quantity: 1,
          price_data: {
            currency: env.stripeCurrency,
            unit_amount: cents(serviceFee),
            product_data: { name: 'Frais de service FAST' },
          },
        },
        ...(deliveryFee > 0
          ? [{
              quantity: 1,
              price_data: {
                currency: env.stripeCurrency,
                unit_amount: cents(deliveryFee),
                product_data: { name: 'Frais de livraison' },
              },
            }]
          : []),
      ],
      payment_intent_data: Object.keys(paymentIntentData).length > 0 ? paymentIntentData : undefined,
      success_url: env.stripeSuccessUrl,
      cancel_url: env.stripeCancelUrl,
    });

    await prisma.paymentCheckout.update({
      where: { id: checkout.id },
      data: { stripeCheckoutSessionId: session.id },
    });

    res.status(201).json({
      sessionId: session.id,
      url: session.url,
      groupOrder: groupOrderResponse,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
};

export const confirmCheckoutSession = async (req: Request, res: Response): Promise<void> => {
  try {
    const stripe = stripeClient();
    const sessionId = req.params.sessionId as string;
    const session = await stripe.checkout.sessions.retrieve(sessionId);

    const checkoutId = session.metadata?.checkoutId;
    if (!checkoutId || session.payment_status !== 'paid') {
      res.status(402).json({ error: 'Paiement non confirmé' });
      return;
    }

    const checkout = await prisma.paymentCheckout.findUnique({ where: { id: checkoutId } });
    if (!checkout || checkout.userId !== req.user!.userId || checkout.stripeCheckoutSessionId !== session.id) {
      res.status(403).json({ error: 'Accès refusé' });
      return;
    }

    const paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id ?? null;

    const order = await createPaidOrderFromCheckout(checkoutId, paymentIntentId);
    res.json(order);
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
};

export const stripeWebhook = async (req: Request, res: Response): Promise<void> => {
  try {
    const stripe = stripeClient();
    const signature = req.headers['stripe-signature'];
    let event: Stripe.Event;

    if (env.stripeWebhookSecret && signature) {
      event = stripe.webhooks.constructEvent(req.body, signature, env.stripeWebhookSecret);
    } else {
      event = JSON.parse(Buffer.isBuffer(req.body) ? req.body.toString('utf8') : String(req.body));
    }

    if (event.type === 'checkout.session.completed') {
      const session = event.data.object as Stripe.Checkout.Session;
      if (session.payment_status === 'paid' && session.metadata?.checkoutId) {
        const paymentIntentId = typeof session.payment_intent === 'string'
          ? session.payment_intent
          : session.payment_intent?.id ?? null;
        await createPaidOrderFromCheckout(session.metadata.checkoutId, paymentIntentId);
      }
    }

    res.json({ received: true });
  } catch (err) {
    res.status(400).json({ error: (err as Error).message });
  }
};

export const checkoutSuccessPage = (req: Request, res: Response): void => {
  const sessionId = typeof req.query.session_id === 'string' ? req.query.session_id : '';
  const deepLink = sessionId
    ? `fast://checkout/success?session_id=${encodeURIComponent(sessionId)}`
    : 'fast://checkout/success';
  res.type('html').send(`<!DOCTYPE html><html><head><meta charset="utf-8"><title>Paiement réussi</title>
<meta http-equiv="refresh" content="0;url=${deepLink}">
<script>window.location.href=${JSON.stringify(deepLink)};</script></head>
<body><h1>Paiement réussi</h1><p>Retour dans FAST… <a href="${deepLink}">Ouvrir l'app</a></p></body></html>`);
};

export const checkoutCancelPage = (_req: Request, res: Response): void => {
  res.type('html').send('<h1>Paiement annulé</h1><p>Vous pouvez retourner dans FAST et réessayer.</p>');
};

export const createConnectAccountLink = async (req: Request, res: Response): Promise<void> => {
  try {
    const stripe = stripeClient();
    const restaurant = await prisma.restaurant.findUnique({ where: { ownerId: req.user!.userId } });
    if (!restaurant) {
      res.status(404).json({ error: 'Restaurant introuvable' });
      return;
    }

    let accountId = restaurant.stripeAccountId;
    if (!accountId) {
      const account = await stripe.accounts.create({
        type: 'express',
        country: 'FR',
        email: undefined,
        capabilities: {
          card_payments: { requested: true },
          transfers: { requested: true },
        },
        business_type: 'company',
        metadata: { restaurantId: restaurant.id, ownerId: req.user!.userId },
      });
      accountId = account.id;
      await prisma.restaurant.update({
        where: { id: restaurant.id },
        data: { stripeAccountId: accountId },
      });
    }

    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      type: 'account_onboarding',
      refresh_url: env.stripeCancelUrl,
      return_url: env.stripeSuccessUrl.replace('{CHECKOUT_SESSION_ID}', ''),
    });

    res.json({ url: accountLink.url, accountId });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
};

export const getConnectStatus = async (req: Request, res: Response): Promise<void> => {
  try {
    const stripe = stripeClient();
    const restaurant = await prisma.restaurant.findUnique({ where: { ownerId: req.user!.userId } });
    if (!restaurant) {
      res.status(404).json({ error: 'Restaurant introuvable' });
      return;
    }
    if (!restaurant.stripeAccountId) {
      res.json({ connected: false, chargesEnabled: false, payoutsEnabled: false });
      return;
    }

    const account = await stripe.accounts.retrieve(restaurant.stripeAccountId);
    await prisma.restaurant.update({
      where: { id: restaurant.id },
      data: {
        stripeChargesEnabled: account.charges_enabled,
        stripePayoutsEnabled: account.payouts_enabled,
      },
    });

    res.json({
      connected: true,
      accountId: restaurant.stripeAccountId,
      chargesEnabled: account.charges_enabled,
      payoutsEnabled: account.payouts_enabled,
    });
  } catch (err) {
    res.status(500).json({ error: (err as Error).message });
  }
};
