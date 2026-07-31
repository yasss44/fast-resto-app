import { Request, Response } from 'express';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { prisma } from '../services/prisma';
import { env } from '../config/env';
import { registerSchema, loginSchema, updateProfileSchema } from '../utils/validation';

export const register = async (req: Request, res: Response): Promise<void> => {
  const data = registerSchema.parse(req.body);

  const existing = await prisma.user.findUnique({ where: { email: data.email } });
  if (existing) {
    res.status(409).json({ error: 'Cet email est déjà utilisé' });
    return;
  }

  const hashedPassword = await bcrypt.hash(data.password, env.bcryptRounds);

  const user = await prisma.user.create({
    data: {
      email: data.email,
      password: hashedPassword,
      name: data.name,
      phone: data.phone,
      role: data.role,
      ...(data.role === 'LIVREUR' && data.driverType
        ? { driverProfile: { create: { type: data.driverType } } }
        : {}),
    },
    include: { driverProfile: true },
  });

  const token = jwt.sign(
    { userId: user.id, role: user.role, tokenVersion: user.tokenVersion },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.status(201).json({
    token,
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points, driverProfile: user.driverProfile },
  });
};

export const login = async (req: Request, res: Response): Promise<void> => {
  const data = loginSchema.parse(req.body);

  const user = await prisma.user.findUnique({
    where: { email: data.email },
    include: { driverProfile: true },
  });
  if (!user) {
    res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    return;
  }

  // Check account lockout
  if (user.lockedUntil && user.lockedUntil > new Date()) {
    const remaining = Math.ceil((user.lockedUntil.getTime() - Date.now()) / 60000);
    res.status(429).json({ error: `Compte temporairement verrouillé. Réessayez dans ${remaining} minute(s).` });
    return;
  }

  const valid = await bcrypt.compare(data.password, user.password);
  if (!valid) {
    // Increment failed attempts
    const failed = (user.failedLoginAttempts || 0) + 1;
    const updateData: any = { failedLoginAttempts: failed };
    if (failed >= env.maxFailedLogins) {
      updateData.lockedUntil = new Date(Date.now() + env.lockoutMinutes * 60 * 1000);
      updateData.failedLoginAttempts = 0;
    }
    await prisma.user.update({ where: { id: user.id }, data: updateData });

    res.status(401).json({ error: 'Email ou mot de passe incorrect' });
    return;
  }

  // Reset failed attempts on successful login
  if (user.failedLoginAttempts !== 0 || user.lockedUntil) {
    await prisma.user.update({
      where: { id: user.id },
      data: { failedLoginAttempts: 0, lockedUntil: null },
    });
  }

  const token = jwt.sign(
    { userId: user.id, role: user.role, tokenVersion: user.tokenVersion },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn as string } as jwt.SignOptions,
  );

  res.json({
    token,
    user: { id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points, driverProfile: user.driverProfile },
  });
};

export const getMe = async (req: Request, res: Response): Promise<void> => {
  const user = await prisma.user.findUnique({
    where: { id: req.user!.userId },
    include: { restaurant: true, driverProfile: { include: { schedules: true } } },
  });

  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }

  res.json({
    id: user.id,
    name: user.name,
    email: user.email,
    phone: user.phone,
    role: user.role,
    points: user.points,
    restaurant: user.restaurant,
    driverProfile: user.driverProfile,
  });
};

export const logout = async (req: Request, res: Response): Promise<void> => {
  // Increment tokenVersion to invalidate all existing tokens
  await prisma.user.update({
    where: { id: req.user!.userId },
    data: { tokenVersion: { increment: 1 } },
  });
  res.json({ message: 'Déconnexion réussie' });
};

export const updateProfile = async (req: Request, res: Response): Promise<void> => {
  const data = updateProfileSchema.parse(req.body);

  const user = await prisma.user.update({
    where: { id: req.user!.userId },
    data: { ...(data.name && { name: data.name }), ...(data.phone && { phone: data.phone }) },
  });

  res.json({ id: user.id, name: user.name, email: user.email, phone: user.phone, role: user.role, points: user.points });
};
