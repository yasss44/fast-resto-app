import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createNotificationSchema } from '../utils/validation';

export const listNotifications = async (req: Request, res: Response): Promise<void> => {
  const notifications = await prisma.notification.findMany({
    where: { userId: req.user!.userId },
    orderBy: { createdAt: 'desc' },
    take: 100,
  });

  res.json(notifications);
};

export const markAsRead = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  await prisma.notification.updateMany({
    where: { id, userId: req.user!.userId },
    data: { isRead: true },
  });

  res.json({ message: 'Notification marquée comme lue' });
};

export const markAllAsRead = async (req: Request, res: Response): Promise<void> => {
  await prisma.notification.updateMany({
    where: { userId: req.user!.userId },
    data: { isRead: true },
  });

  res.json({ message: 'Toutes les notifications marquées comme lues' });
};

export const deleteNotification = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  await prisma.notification.deleteMany({
    where: { id, userId: req.user!.userId },
  });

  res.json({ message: 'Notification supprimée' });
};

export const clearAllNotifications = async (req: Request, res: Response): Promise<void> => {
  await prisma.notification.deleteMany({
    where: { userId: req.user!.userId },
  });

  res.json({ message: 'Notifications effacées' });
};

export const createNotification = async (req: Request, res: Response): Promise<void> => {
  const data = createNotificationSchema.parse(req.body);

  const notification = await prisma.notification.create({
    data: {
      ...data,
      userId: req.user!.userId,
    },
  });

  res.status(201).json(notification);
};
