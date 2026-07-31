import { Request, Response } from 'express';
import { randomBytes } from 'crypto';
import { prisma } from '../services/prisma';
import { createGroupSchema, joinGroupSchema, updateGroupMemberSchema, saveGroupCartSchema } from '../utils/validation';
import { computeCartPricing } from '../utils/cartPricing';

function generateCode(): string {
  return `FAST-${randomBytes(6).toString('base64url').toUpperCase()}`;
}

const safeGroupInclude = {
  restaurant: { select: { id: true, name: true, image: true, isActive: true } },
  host: { select: { id: true, name: true } },
  members: {
    include: { user: { select: { id: true, name: true } } },
    orderBy: { createdAt: 'asc' as const },
  },
};

export const createGroup = async (req: Request, res: Response): Promise<void> => {
  const data = createGroupSchema.parse(req.body);
  const restaurant = await prisma.restaurant.findFirst({
    where: { id: data.restaurantId, isActive: true },
    select: { id: true },
  });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable ou inactif' });
    return;
  }

  let group = null;
  for (let attempts = 0; attempts < 5; attempts++) {
    try {
      group = await prisma.groupOrder.create({
        data: {
          code: generateCode(),
          hostUserId: req.user!.userId,
          restaurantId: restaurant.id,
          members: {
            create: {
              userId: req.user!.userId,
              role: 'HOST',
            },
          },
        },
        include: safeGroupInclude,
      });
      break;
    } catch (e: unknown) {
      if ((e as { code?: string }).code === 'P2002' && attempts < 4) {
        continue;
      }
      throw e;
    }
  }

  if (!group) {
    res.status(503).json({ error: 'Impossible de générer un code de groupe unique' });
    return;
  }
  res.status(201).json(group);
};

export const joinGroup = async (req: Request, res: Response): Promise<void> => {
  const { code } = joinGroupSchema.parse(req.body);

  const group = await prisma.groupOrder.findUnique({
    where: { code: code.toUpperCase() },
    include: { members: true },
  });

  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }

  if (group.status !== 'OPEN') {
    res.status(400).json({ error: 'Ce groupe n\'est plus ouvert' });
    return;
  }

  // Check if already a member
  const alreadyMember = group.members.some((m) => m.userId === req.user!.userId);
  if (alreadyMember) {
    res.status(400).json({ error: 'Vous êtes déjà membre de ce groupe' });
    return;
  }

  const member = await prisma.groupMember.create({
    data: {
      groupId: group.id,
      userId: req.user!.userId,
      role: 'MEMBER',
    },
    include: {
      user: { select: { id: true, name: true } },
    },
  });

  const updated = await prisma.groupOrder.findUnique({
    where: { id: group.id },
    include: safeGroupInclude,
  });

  void member;
  res.json(updated);
};

export const getMyGroups = async (req: Request, res: Response): Promise<void> => {
  const groups = await prisma.groupOrder.findMany({
    where: {
      members: {
        some: { userId: req.user!.userId },
      },
    },
    include: safeGroupInclude,
    orderBy: { createdAt: 'desc' },
  });

  res.json(groups);
};

export const getGroup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const group = await prisma.groupOrder.findUnique({
    where: { id },
    include: safeGroupInclude,
  });

  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }

  // Only host or members can view the group
  const isMember = group.members.some((m) => m.userId === req.user!.userId);
  if (!isMember) {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }

  res.json(group);
};

export const leaveGroup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const group = await prisma.groupOrder.findUnique({
    where: { id },
    include: {
      members: true,
      orders: { where: { paymentStatus: 'PAID' }, select: { id: true } },
    },
  });

  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }

  const member = group.members.find((m) => m.userId === req.user!.userId);
  if (!member) {
    res.status(400).json({ error: 'Vous n\'êtes pas membre de ce groupe' });
    return;
  }

  const hasPayment = group.orders.length > 0
    || group.members.some((groupMember) => groupMember.paymentStatus === 'PAID');

  if (member.role === 'HOST') {
    if (hasPayment) {
      res.status(409).json({ error: 'Le groupe ne peut plus être annulé après un paiement' });
      return;
    }
    if (!['OPEN', 'LOCKED'].includes(group.status)) {
      res.status(409).json({ error: 'Ce groupe ne peut plus être annulé' });
      return;
    }
    await prisma.groupOrder.update({
      where: { id },
      data: { status: 'CANCELLED' },
    });
    res.json({ message: 'Groupe annulé' });
    return;
  }

  if (group.status !== 'OPEN') {
    res.status(409).json({ error: 'Vous ne pouvez quitter qu’un groupe ouvert' });
    return;
  }
  if (member.paymentStatus === 'PAID') {
    res.status(409).json({ error: 'Vous ne pouvez plus quitter le groupe après votre paiement' });
    return;
  }

  await prisma.groupMember.delete({
    where: { id: member.id },
  });

  res.json({ message: 'Vous avez quitté le groupe' });
};

export const saveGroupCart = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const { items } = saveGroupCartSchema.parse(req.body);

  const group = await prisma.groupOrder.findUnique({
    where: { id },
    select: { status: true, restaurantId: true },
  });
  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }
  if (group.status !== 'OPEN') {
    res.status(409).json({ error: 'Le panier ne peut plus être modifié' });
    return;
  }

  const member = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: id, userId: req.user!.userId } },
  });
  if (!member) {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }
  if (member.paymentStatus === 'PAID') {
    res.status(409).json({ error: 'La part payée ne peut plus être modifiée' });
    return;
  }

  let pricing;
  try {
    pricing = items.length > 0
      ? await computeCartPricing(group.restaurantId, items)
      : { itemsCount: 0, subtotal: 0 };
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

  const updated = await prisma.groupMember.update({
    where: { id: member.id },
    data: {
      cartItemsJson: JSON.stringify(items),
      itemsCount: pricing.itemsCount,
      total: pricing.subtotal,
      isReady: items.length > 0,
    },
    include: { user: { select: { id: true, name: true } } },
  });

  res.json(updated);
};

export const getGroupCarts = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;

  const group = await prisma.groupOrder.findUnique({
    where: { id },
    include: {
      members: {
        include: { user: { select: { id: true, name: true } } },
        orderBy: { createdAt: 'asc' },
      },
    },
  });
  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }

  const isMember = group.members.some((m) => m.userId === req.user!.userId);
  if (!isMember) {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }

  const carts = group.members.map((member) => ({
    userId: member.userId,
    userName: member.user.name,
    role: member.role,
    itemsCount: member.itemsCount,
    total: member.total,
    isReady: member.isReady,
    paymentStatus: member.paymentStatus,
    items: member.cartItemsJson
      ? JSON.parse(member.cartItemsJson)
      : [],
  }));

  res.json({ groupId: group.id, carts });
};

export const updateMyGroupMember = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const data = updateGroupMemberSchema.parse(req.body);
  const group = await prisma.groupOrder.findUnique({
    where: { id },
    select: { status: true, restaurantId: true },
  });
  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }
  if (group.status !== 'OPEN') {
    res.status(409).json({ error: 'Le panier ne peut plus être modifié' });
    return;
  }

  const member = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: id, userId: req.user!.userId } },
  });
  if (!member) {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }
  if (member.paymentStatus === 'PAID') {
    res.status(409).json({ error: 'La part payée ne peut plus être modifiée' });
    return;
  }

  let updateData = { ...data };
  if (member.cartItemsJson) {
    try {
      const cartItems = JSON.parse(member.cartItemsJson);
      if (Array.isArray(cartItems) && cartItems.length > 0) {
        const pricing = await computeCartPricing(group.restaurantId, cartItems);
        updateData = {
          ...data,
          itemsCount: pricing.itemsCount,
          total: pricing.subtotal,
        };
      }
    } catch {
      // Keep client-provided values if cart parsing fails
    }
  }

  const updated = await prisma.groupMember.update({
    where: { id: member.id },
    data: updateData,
    include: { user: { select: { id: true, name: true } } },
  });
  res.json(updated);
};

export const updateMyPaymentStatus = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const paymentStatus = req.body?.paymentStatus;
  if (paymentStatus !== 'READY' && paymentStatus !== 'DRAFT') {
    res.status(400).json({ error: 'paymentStatus doit valoir READY ou DRAFT' });
    return;
  }

  const member = await prisma.groupMember.findUnique({
    where: { groupId_userId: { groupId: id, userId: req.user!.userId } },
    include: { group: { select: { status: true } } },
  });
  if (!member) {
    res.status(403).json({ error: 'Accès interdit' });
    return;
  }
  if (member.group.status !== 'OPEN') {
    res.status(409).json({ error: 'Le groupe n’est plus ouvert' });
    return;
  }
  if (member.paymentStatus === 'PAID') {
    res.status(409).json({ error: 'Un paiement confirmé ne peut pas être annulé' });
    return;
  }

  const updated = await prisma.groupMember.update({
    where: { id: member.id },
    data: { paymentStatus, isReady: paymentStatus === 'READY' },
    include: { user: { select: { id: true, name: true } } },
  });
  res.json(updated);
};

export const lockGroup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const group = await prisma.groupOrder.findUnique({
    where: { id },
    select: { hostUserId: true, status: true },
  });
  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }
  if (group.hostUserId !== req.user!.userId) {
    res.status(403).json({ error: 'Action réservée à l’hôte' });
    return;
  }
  if (group.status !== 'OPEN') {
    res.status(409).json({ error: 'Seul un groupe ouvert peut être verrouillé' });
    return;
  }

  const updated = await prisma.groupOrder.update({
    where: { id },
    data: { status: 'LOCKED' },
    include: safeGroupInclude,
  });
  res.json(updated);
};

export const submitGroup = async (req: Request, res: Response): Promise<void> => {
  const id = req.params.id as string;
  const group = await prisma.groupOrder.findUnique({
    where: { id },
    include: {
      members: { select: { paymentStatus: true } },
      orders: {
        where: { paymentStatus: 'PAID' },
        select: { id: true, userId: true },
      },
      restaurant: { select: { ownerId: true } },
    },
  });
  if (!group) {
    res.status(404).json({ error: 'Groupe introuvable' });
    return;
  }
  if (group.hostUserId !== req.user!.userId) {
    res.status(403).json({ error: 'Action réservée à l’hôte' });
    return;
  }
  if (group.status !== 'LOCKED') {
    res.status(409).json({ error: 'Le groupe doit être verrouillé avant envoi' });
    return;
  }
  if (!group.members.some((member) => member.paymentStatus === 'PAID') || group.orders.length === 0) {
    res.status(409).json({ error: 'Au moins une part payée est requise' });
    return;
  }

  const submittedAt = new Date();
  const updated = await prisma.$transaction(async (tx) => {
    const result = await tx.groupOrder.updateMany({
      where: { id, status: 'LOCKED' },
      data: { status: 'SUBMITTED', submittedAt },
    });
    if (result.count !== 1) {
      throw new Error('GROUP_ALREADY_SUBMITTED');
    }
    await tx.notification.create({
      data: {
        userId: group.restaurant.ownerId,
        title: 'Nouvelle commande groupée payée !',
        body: `Groupe ${group.code} — ${group.orders.length} part(s) payée(s)`,
        type: 'STATUS',
      },
    });
    return tx.groupOrder.findUnique({
      where: { id },
      include: safeGroupInclude,
    });
  });

  res.json({
    ...updated,
    submittedOrderIds: group.orders.map((order) => order.id),
    excludedUnpaidMembers: group.members.filter((member) => member.paymentStatus !== 'PAID').length,
  });
};
