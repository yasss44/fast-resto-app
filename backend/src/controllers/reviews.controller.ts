import { Request, Response } from 'express';
import { prisma } from '../services/prisma';
import { createReviewSchema } from '../utils/validation';

export const createReview = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;
  const data = createReviewSchema.parse(req.body);

  const restaurant = await prisma.restaurant.findUnique({ where: { id: restaurantId } });
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const user = await prisma.user.findUnique({ where: { id: req.user!.userId } });
  if (!user) {
    res.status(404).json({ error: 'Utilisateur introuvable' });
    return;
  }

  if (data.orderId) {
    const existingReview = await prisma.review.findUnique({
      where: {
        userId_orderId: {
          userId: req.user!.userId,
          orderId: data.orderId,
        },
      },
    });
    if (existingReview) {
      res.status(409).json({ error: 'Vous avez déjà laissé un avis pour cette commande' });
      return;
    }

    const order = await prisma.order.findFirst({
      where: {
        id: data.orderId,
        userId: req.user!.userId,
        restaurantId,
        status: 'COMPLETED',
      },
    });
    if (!order) {
      res.status(403).json({ error: 'Commande invalide ou non complétée pour cet avis' });
      return;
    }
  } else {
    const completedOrder = await prisma.order.findFirst({
      where: {
        userId: req.user!.userId,
        restaurantId,
        status: 'COMPLETED',
      },
    });
    if (!completedOrder) {
      res.status(403).json({ error: 'Vous devez avoir une commande récupérée dans ce restaurant pour laisser un avis' });
      return;
    }
  }

  const review = await prisma.review.create({
    data: {
      restaurantId,
      userId: req.user!.userId,
      orderId: data.orderId ?? null,
      userName: user.name,
      rating: data.rating,
      comment: data.comment || '',
    },
  });

  const aggregations = await prisma.review.aggregate({
    where: { restaurantId },
    _avg: { rating: true },
    _count: true,
  });

  await prisma.restaurant.update({
    where: { id: restaurantId },
    data: {
      rating: Math.round((aggregations._avg.rating || 0) * 10) / 10,
      reviewsCount: aggregations._count,
    },
  });

  if (data.orderId) {
    await prisma.order.update({
      where: { id: data.orderId },
      data: { ratingSubmitted: true },
    });
  }

  res.status(201).json(review);
};

export const listReviews = async (req: Request, res: Response): Promise<void> => {
  const restaurantId = req.params.restaurantId as string;

  const reviews = await prisma.review.findMany({
    where: { restaurantId },
    include: { user: { select: { name: true } } },
    orderBy: { createdAt: 'desc' },
    take: 50,
  });

  res.json(reviews);
};
