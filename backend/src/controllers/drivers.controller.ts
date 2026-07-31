import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import {
  replaceDriverSchedulesSchema,
  updateDriverAvailabilitySchema,
} from '../utils/validation';

const profileInclude = { schedules: { orderBy: [{ dayOfWeek: 'asc' as const }, { startMinute: 'asc' as const }] } };

export const getDriverProfile = async (req: Request, res: Response): Promise<void> => {
  const profile = await prisma.driverProfile.findUnique({
    where: { userId: req.user!.userId },
    include: profileInclude,
  });
  if (!profile) {
    res.status(404).json({ error: 'Profil livreur introuvable' });
    return;
  }
  res.json(profile);
};

export const updateDriverAvailability = async (req: Request, res: Response): Promise<void> => {
  const data = updateDriverAvailabilitySchema.parse(req.body);
  const profile = await prisma.driverProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) {
    res.status(404).json({ error: 'Profil livreur introuvable' });
    return;
  }

  if (profile.type === 'PERMANENT' && data.isOnline === true) {
    const schedules = await prisma.driverSchedule.count({
      where: { driverProfileId: profile.id, isEnabled: true },
    });
    if (schedules === 0) {
      res.status(400).json({ error: 'Ajoutez au moins un créneau permanent avant de vous mettre en ligne' });
      return;
    }
  }

  const updated = await prisma.driverProfile.update({
    where: { id: profile.id },
    data,
    include: profileInclude,
  });
  res.json(updated);
};

export const replaceDriverSchedules = async (req: Request, res: Response): Promise<void> => {
  const data = replaceDriverSchedulesSchema.parse(req.body);
  const profile = await prisma.driverProfile.findUnique({
    where: { userId: req.user!.userId },
  });
  if (!profile) {
    res.status(404).json({ error: 'Profil livreur introuvable' });
    return;
  }
  if (profile.type !== 'PERMANENT') {
    res.status(400).json({ error: 'Les créneaux sont réservés aux livreurs permanents' });
    return;
  }

  await prisma.$transaction([
    prisma.driverSchedule.deleteMany({ where: { driverProfileId: profile.id } }),
    ...data.schedules.map((slot) => prisma.driverSchedule.create({
      data: { driverProfileId: profile.id, ...slot },
    })),
    prisma.driverProfile.update({
      where: { id: profile.id },
      data: { timezone: data.timezone, isOnline: false },
    }),
  ]);

  const updated = await prisma.driverProfile.findUnique({
    where: { id: profile.id },
    include: profileInclude,
  });
  res.json(updated);
};
