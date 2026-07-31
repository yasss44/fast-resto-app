import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { updateDeliveryStatusSchema } from '../utils/validation';
import {
  safeEmitNotificationToUser,
  safeEmitOrderStatusToUser,
} from '../services/realtime';

const DELIVERY_STATUS_LABELS: Record<string, string> = {
  ACCEPTED: 'Livreur assigné',
  AT_RESTAURANT: 'Livreur au restaurant',
  PICKED_UP: 'En route vers vous',
  DELIVERED: 'Livré',
  CANCELLED: 'Livraison annulée',
};

async function getEligibleDriver(userId: string) {
  const profile = await prisma.driverProfile.findUnique({
    where: { userId },
    include: { schedules: { where: { isEnabled: true } } },
  });
  if (!profile || !profile.isOnline || profile.isPaused) return null;
  if (profile.type === 'OCCASIONAL') return profile;

  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone: profile.timezone,
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(new Date());
  const value = (type: string) => parts.find((part) => part.type === type)?.value || '';
  const weekdays: Record<string, number> = {
    Mon: 1, Tue: 2, Wed: 3, Thu: 4, Fri: 5, Sat: 6, Sun: 7,
  };
  const dayOfWeek = weekdays[value('weekday')];
  const minute = Number(value('hour')) * 60 + Number(value('minute'));
  const inSchedule = profile.schedules.some((slot) =>
    slot.dayOfWeek === dayOfWeek && minute >= slot.startMinute && minute < slot.endMinute);
  return inSchedule ? profile : null;
}

export const getAvailableDeliveries = async (req: Request, res: Response): Promise<void> => {
  if (!await getEligibleDriver(req.user!.userId)) {
    res.status(403).json({ error: 'Mettez-vous en ligne pendant un créneau autorisé pour voir les livraisons' });
    return;
  }
  const deliveries = await prisma.delivery.findMany({
    where: { status: 'AVAILABLE' },
    orderBy: { createdAt: 'desc' },
    take: 20,
  });

  res.json(deliveries);
};

export const acceptDelivery = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  if (!await getEligibleDriver(req.user!.userId)) {
    res.status(403).json({ error: 'Vous devez être disponible pour accepter une livraison' });
    return;
  }

  const activeDelivery = await prisma.delivery.findFirst({
    where: {
      driverId: req.user!.userId,
      status: { in: ['ACCEPTED', 'AT_RESTAURANT', 'PICKED_UP'] },
    },
  });

  if (activeDelivery) {
    res.status(400).json({ error: 'Vous avez déjà une livraison en cours' });
    return;
  }

  const claim = await prisma.delivery.updateMany({
    where: { id, status: 'AVAILABLE', driverId: null },
    data: {
      driverId: req.user!.userId,
      status: 'ACCEPTED',
      acceptedAt: new Date(),
    },
  });

  if (claim.count === 0) {
    res.status(409).json({ error: 'Cette livraison n\'est plus disponible' });
    return;
  }

  const updated = await prisma.delivery.findUnique({ where: { id } });
  if (updated?.orderId) {
    const order = await prisma.order.findUnique({
      where: { id: updated.orderId },
      select: { userId: true },
    });
    if (order) {
      const notification = await prisma.notification.create({
        data: {
          userId: order.userId,
          orderId: updated.orderId,
          title: 'Livreur assigné',
          body: 'Un livreur FAST a accepté votre commande.',
          type: 'STATUS',
        },
      });
      safeEmitNotificationToUser(order.userId, notification);
      safeEmitOrderStatusToUser(order.userId, {
        orderId: updated.orderId,
        status: 'DELIVERY_ACCEPTED',
        deliveryStatus: 'ACCEPTED',
      });
    }
  }

  res.json(updated);
};

export const updateDeliveryStatus = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateDeliveryStatusSchema.parse(req.body);

  const delivery = await prisma.delivery.findUnique({ where: { id } });
  if (!delivery) {
    res.status(404).json({ error: 'Livraison introuvable' });
    return;
  }

  if (delivery.driverId !== req.user!.userId) {
    res.status(403).json({ error: 'Cette livraison ne vous est pas assignée' });
    return;
  }

  const updateData: Record<string, unknown> = { status: data.status };
  if (data.status === 'DELIVERED') {
    updateData.completedAt = new Date();
  }

  const updated = await prisma.delivery.update({
    where: { id },
    data: updateData,
  });

  if (delivery.orderId) {
    const order = await prisma.order.findUnique({
      where: { id: delivery.orderId },
      select: { id: true, userId: true, status: true },
    });

    if (order) {
      const label = DELIVERY_STATUS_LABELS[data.status] ?? data.status;
      const notification = await prisma.notification.create({
        data: {
          userId: order.userId,
          orderId: order.id,
          title: label,
          body: data.status === 'PICKED_UP'
            ? 'Votre commande est en route !'
            : data.status === 'DELIVERED'
              ? 'Bon appétit — commande livrée.'
              : `Statut livraison : ${label}`,
          type: data.status === 'DELIVERED' ? 'SUCCESS' : 'STATUS',
        },
      });
      safeEmitNotificationToUser(order.userId, notification);
      safeEmitOrderStatusToUser(order.userId, {
        orderId: order.id,
        status: order.status,
        deliveryStatus: data.status,
      });

      if (data.status === 'DELIVERED' && order.status !== 'COMPLETED') {
        await prisma.order.update({
          where: { id: order.id },
          data: { status: 'COMPLETED' },
        });
        await prisma.user.update({
          where: { id: order.userId },
          data: { points: { increment: 10 } },
        });
        await prisma.notification.create({
          data: {
            userId: order.userId,
            orderId: order.id,
            title: 'Notez votre commande',
            body: 'Comment s\'est passée votre livraison ?',
            type: 'RATING',
          },
        });
      }
    }
  }

  res.json(updated);
};

export const getMyActiveDelivery = async (req: Request, res: Response): Promise<void> => {
  const delivery = await prisma.delivery.findFirst({
    where: {
      driverId: req.user!.userId,
      status: { in: ['ACCEPTED', 'AT_RESTAURANT', 'PICKED_UP'] },
    },
  });

  if (!delivery) {
    res.json(null);
    return;
  }

  res.json(delivery);
};

export const getOrderDeliveryForClient = async (req: Request, res: Response): Promise<void> => {
  const orderId = req.params.orderId as string;

  const order = await prisma.order.findFirst({
    where: { id: orderId, userId: req.user!.userId },
    select: { id: true, fulfillmentType: true, deliveryAddress: true, status: true },
  });
  if (!order) {
    res.status(404).json({ error: 'Commande introuvable' });
    return;
  }
  if (order.fulfillmentType !== 'DELIVERY') {
    res.status(400).json({ error: 'Cette commande n\'est pas une livraison' });
    return;
  }

  const delivery = await prisma.delivery.findUnique({
    where: { orderId },
    include: {
      driver: { select: { id: true, name: true, phone: true } },
    },
  });

  res.json({
    orderId: order.id,
    orderStatus: order.status,
    deliveryAddress: order.deliveryAddress,
    delivery,
  });
};
