import { Request, Response } from 'express';
import Stripe from 'stripe';
import { OrderStatus } from '@prisma/client';
import { prisma } from '../services/prisma';
import {
  placeOrderSchema,
  updateOrderStatusSchema,
  updateOrderTrackingSchema,
  verifyPickupSchema,
} from '../utils/validation';
import { isValidStatusTransition, STATUS_LABELS } from '../utils/orderStatus';
import {
  safeEmitNotificationToUser,
  safeEmitOrderStatusToUser,
} from '../services/realtime';
import { env } from '../config/env';

function stripeClient(): Stripe | null {
  if (!env.stripeSecretKey) return null;
  return new Stripe(env.stripeSecretKey);
}

const orderInclude = {
  items: { include: { menuItem: true } },
  restaurant: { select: { id: true, name: true, image: true, ownerId: true } },
  groupOrder: { select: { code: true, status: true } },
};

async function refundPaidOrder(order: {
  id: string;
  paymentStatus: string;
  stripePaymentIntentId: string | null;
  stripeCheckoutSessionId: string | null;
  total: number;
  serviceFee: number;
}): Promise<void> {
  if (order.paymentStatus !== 'PAID') return;

  const stripe = stripeClient();
  if (!stripe) return;

  let paymentIntentId = order.stripePaymentIntentId;
  if (!paymentIntentId && order.stripeCheckoutSessionId) {
    const session = await stripe.checkout.sessions.retrieve(order.stripeCheckoutSessionId);
    paymentIntentId = typeof session.payment_intent === 'string'
      ? session.payment_intent
      : session.payment_intent?.id ?? null;
  }
  if (!paymentIntentId) return;

  const refundAmountCents = Math.round((order.total - order.serviceFee) * 100);
  if (refundAmountCents <= 0) return;

  await stripe.refunds.create({
    payment_intent: paymentIntentId,
    amount: refundAmountCents,
  });

  await prisma.order.update({
    where: { id: order.id },
    data: { paymentStatus: 'REFUNDED' },
  });
}

export const placeOrder = async (req: Request, res: Response): Promise<void> => {
  placeOrderSchema.parse(req.body);
  res.status(402).json({ error: 'Paiement Stripe requis. Utilisez /api/payments/checkout-session.' });
};

export const getOrder = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const order = await prisma.order.findUnique({
    where: { id },
    include: orderInclude,
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  const isOwner = order.userId === req.user!.userId;
  const isRestaurantOwner = order.restaurant.ownerId === req.user!.userId;
  if (!isOwner && !isRestaurantOwner) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  res.json(order);
};

export const getMyOrders = async (req: Request, res: Response): Promise<void> => {
  const { status } = req.query;

  const where: Record<string, unknown> = { userId: req.user!.userId };
  if (status && typeof status === 'string') {
    where.status = status;
  }

  const orders = await prisma.order.findMany({
    where,
    include: {
      items: { include: { menuItem: true } },
      restaurant: { select: { id: true, name: true, image: true } },
      groupOrder: { select: { code: true, status: true } },
      delivery: { select: { id: true, status: true, driverId: true, destination: true } },
    },
    orderBy: { createdAt: 'desc' },
  });

  res.json(orders);
};

export const getRestaurantOrders = async (req: Request, res: Response): Promise<void> => {
  const { status } = req.query;

  const restaurant = await prisma.restaurant.findFirst({
    where: { ownerId: req.user!.userId },
  });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const where: Record<string, unknown> = {
    restaurantId: restaurant.id,
    OR: [
      { groupOrderId: null },
      { groupOrder: { status: 'SUBMITTED' } },
    ],
  };
  if (status && typeof status === 'string') {
    where.status = status;
  }

  const orders = await prisma.order.findMany({
    where,
    include: {
      items: { include: { menuItem: true } },
      user: { select: { id: true, name: true } },
      groupOrder: { select: { code: true, status: true } },
    },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  res.json(orders);
};

export const updateOrderTracking = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateOrderTrackingSchema.parse(req.body);

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  const updateData: Record<string, unknown> = {};
  if (data.gpsProgress !== undefined) updateData.gpsProgress = data.gpsProgress;
  if (data.isReadyAtEntrance !== undefined) updateData.isReadyAtEntrance = data.isReadyAtEntrance;

  const updated = await prisma.order.update({
    where: { id },
    data: updateData,
    include: orderInclude,
  });

  res.json(updated);
};

export const verifyPickup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { token } = verifyPickupSchema.parse(req.body);

  const order = await prisma.order.findUnique({
    where: { id },
    include: { restaurant: true },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (order.restaurant.ownerId !== req.user!.userId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }

  if (order.status !== 'READY_FOR_PICKUP') {
    res.status(409).json({ error: 'La commande doit être prête pour retrait' });
    return;
  }

  if (!order.pickupToken || order.pickupToken !== token) {
    res.status(400).json({ error: 'Token de retrait invalide' });
    return;
  }

  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.order.update({
      where: { id },
      data: { status: 'COMPLETED', isReadyAtEntrance: true },
      include: orderInclude,
    });

    await tx.user.update({
      where: { id: order.userId },
      data: { points: { increment: 10 } },
    });

    const statusNotification = await tx.notification.create({
      data: {
        userId: order.userId,
        orderId: order.id,
        title: STATUS_LABELS.COMPLETED,
        body: 'Votre commande a été récupérée avec succès.',
        type: 'SUCCESS',
      },
    });

    const ratingNotification = await tx.notification.create({
      data: {
        userId: order.userId,
        orderId: order.id,
        title: 'Notez votre commande',
        body: 'Comment s\'est passée votre expérience ? Laissez un avis.',
        type: 'RATING',
      },
    });

    return { order: result, statusNotification, ratingNotification };
  });

  safeEmitOrderStatusToUser(order.userId, {
    orderId: order.id,
    status: 'COMPLETED',
  });
  safeEmitNotificationToUser(order.userId, updated.statusNotification);
  safeEmitNotificationToUser(order.userId, updated.ratingNotification);

  res.json(updated.order);
};

export const updateOrderStatus = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateOrderStatusSchema.parse(req.body);

  const order = await prisma.order.findUnique({
    where: { id },
    include: {
      restaurant: true,
      groupOrder: { select: { status: true } },
    },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  const rest = order.restaurant;
  if (rest.ownerId !== req.user!.userId) {
    res.status(403).json({ error: 'Accès refusé' });
    return;
  }
  if (order.groupOrder && order.groupOrder.status !== 'SUBMITTED') {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }

  if (!isValidStatusTransition(order.status, data.status as OrderStatus)) {
    res.status(400).json({
      error: `Transition de statut invalide : ${order.status} → ${data.status}`,
    });
    return;
  }

  const updateData: Record<string, unknown> = { status: data.status };
  if (data.status === 'PREPARING') {
    updateData.prepStartedAt = new Date();
    const prepTime = rest.isRushMode ? rest.rushPrepTime : rest.normalPrepTime;
    updateData.prepTimerSeconds = prepTime * 60;
  }
  if (data.status === 'CANCELLED' && data.isBilledAnyway) {
    updateData.isBilledAnyway = true;
  }
  if (data.status === 'COMPLETED') {
    updateData.isReadyAtEntrance = true;
    await prisma.user.update({
      where: { id: order.userId },
      data: { points: { increment: 10 } },
    });
  }

  const updated = await prisma.order.update({
    where: { id },
    data: updateData,
    include: {
      items: { include: { menuItem: true } },
      restaurant: true,
      groupOrder: { select: { code: true, status: true } },
    },
  });

  const label = STATUS_LABELS[data.status] || data.status;
  const notification = await prisma.notification.create({
    data: {
      userId: order.userId,
      orderId: order.id,
      title: label,
      body: data.status === 'PREPARING'
        ? 'Le restaurant prépare votre commande.'
        : data.status === 'READY_FOR_PICKUP'
          ? 'Votre repas est chaud et prêt à être récupéré !'
          : `Statut mis à jour : ${label}`,
      type: data.status === 'COMPLETED' ? 'SUCCESS' : 'STATUS',
    },
  });

  safeEmitOrderStatusToUser(order.userId, {
    orderId: order.id,
    status: data.status,
  });
  safeEmitNotificationToUser(order.userId, notification);

  if (data.status === 'COMPLETED') {
    const ratingNotification = await prisma.notification.create({
      data: {
        userId: order.userId,
        orderId: order.id,
        title: 'Notez votre commande',
        body: 'Comment s\'est passée votre expérience ? Laissez un avis.',
        type: 'RATING',
      },
    });
    safeEmitNotificationToUser(order.userId, ratingNotification);
  }

  res.json(updated);
};

export const cancelMyOrder = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const order = await prisma.order.findFirst({
    where: { id, userId: req.user!.userId },
    include: { groupOrder: { select: { code: true, status: true } } },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }
  if (order.groupOrder) {
    res.status(409).json({
      error: `La part payée du groupe ${order.groupOrder.code} ne peut pas être annulée individuellement`,
    });
    return;
  }

  if (order.status === 'CANCELLED' || order.status === 'COMPLETED') {
    res.status(409).json({ error: 'Cette commande ne peut plus être annulée' });
    return;
  }

  if (order.status !== 'PLACED') {
    await prisma.order.update({
      where: { id },
      data: { status: 'CANCELLED', isBilledAnyway: true },
    });
    res.json({ message: 'Commande annulée. La préparation avait commencé, le montant est facturé.' });
    return;
  }

  if (order.paymentStatus === 'PAID') {
    try {
      await refundPaidOrder(order);
    } catch (err) {
      res.status(500).json({ error: `Échec du remboursement : ${(err as Error).message}` });
      return;
    }
  }

  await prisma.order.update({
    where: { id },
    data: { status: 'CANCELLED' },
  });

  res.json({ message: 'Commande annulée. Remboursement effectué (hors frais de service).' });
};
