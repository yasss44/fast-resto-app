import { Request, Response } from 'express';
import { prisma } from '../services/prisma';

const ALLOWED_PERIODS = new Set([7, 30, 90]);

type RevenueOrder = {
  userId: string;
  subtotal: number;
  createdAt: Date;
};

const percentageDelta = (current: number, previous: number): number | null => {
  if (previous === 0) return current === 0 ? 0 : null;
  return Math.round(((current - previous) / previous) * 1000) / 10;
};

const roundMoney = (value: number): number => Math.round(value * 100) / 100;

async function getRestaurantForOwner(userId: string) {
  return prisma.restaurant.findFirst({
    where: { ownerId: userId },
  });
}

function buildPeriodRange(days: number) {
  const now = new Date();
  const periodEnd = new Date(Date.UTC(
    now.getUTCFullYear(),
    now.getUTCMonth(),
    now.getUTCDate() + 1,
  ));
  const periodStart = new Date(periodEnd);
  periodStart.setUTCDate(periodStart.getUTCDate() - days);
  const previousStart = new Date(periodStart);
  previousStart.setUTCDate(previousStart.getUTCDate() - days);
  return { periodStart, periodEnd, previousStart };
}

export const getStats = async (req: Request, res: Response): Promise<void> => {
  const days = Number(req.query.period ?? 7);
  if (!Number.isInteger(days) || !ALLOWED_PERIODS.has(days)) {
    res.status(400).json({ error: 'La période doit être de 7, 30 ou 90 jours' });
    return;
  }

  const restaurant = await getRestaurantForOwner(req.user!.userId);
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const restaurantId = restaurant.id;
  const { periodStart, periodEnd, previousStart } = buildPeriodRange(days);

  const revenueOrderFilter = {
    restaurantId,
    status: 'COMPLETED' as const,
    paymentStatus: 'PAID' as const,
  };

  const [
    currentOrders,
    previousOrders,
    customersBeforePeriod,
    allCurrentOrders,
    currentCancelledOrders,
    previousAllOrders,
    previousCancelledOrders,
    soldItems,
  ] = await Promise.all([
    prisma.order.findMany({
      where: {
        ...revenueOrderFilter,
        createdAt: { gte: periodStart, lt: periodEnd },
      },
      select: { userId: true, subtotal: true, createdAt: true },
    }),
    prisma.order.findMany({
      where: {
        ...revenueOrderFilter,
        createdAt: { gte: previousStart, lt: periodStart },
      },
      select: { userId: true, subtotal: true, createdAt: true },
    }),
    prisma.order.findMany({
      where: {
        ...revenueOrderFilter,
        createdAt: { lt: periodStart },
      },
      distinct: ['userId'],
      select: { userId: true },
    }),
    prisma.order.count({
      where: { restaurantId, createdAt: { gte: periodStart, lt: periodEnd } },
    }),
    prisma.order.count({
      where: {
        restaurantId,
        status: 'CANCELLED',
        createdAt: { gte: periodStart, lt: periodEnd },
      },
    }),
    prisma.order.count({
      where: { restaurantId, createdAt: { gte: previousStart, lt: periodStart } },
    }),
    prisma.order.count({
      where: {
        restaurantId,
        status: 'CANCELLED',
        createdAt: { gte: previousStart, lt: periodStart },
      },
    }),
    prisma.cartItem.findMany({
      where: {
        order: {
          ...revenueOrderFilter,
          createdAt: { gte: periodStart, lt: periodEnd },
        },
      },
      select: {
        menuItemId: true,
        quantity: true,
        menuItem: { select: { name: true } },
      },
    }),
  ]);

  const currentRevenue = roundMoney(
    currentOrders.reduce((sum: number, order: RevenueOrder) => sum + order.subtotal, 0),
  );
  const previousRevenue = roundMoney(
    previousOrders.reduce((sum: number, order: RevenueOrder) => sum + order.subtotal, 0),
  );
  const currentCustomerIds = new Set(currentOrders.map((order: RevenueOrder) => order.userId));
  const previousCustomerIds = new Set(previousOrders.map((order: RevenueOrder) => order.userId));
  const knownCustomerIds = new Set(customersBeforePeriod.map(({ userId }) => userId));
  const recurringCustomerIds = new Set(
    [...currentCustomerIds].filter((userId) => knownCustomerIds.has(userId)),
  );
  const newCustomers = currentCustomerIds.size - recurringCustomerIds.size;
  const recurringRevenue = roundMoney(
    currentOrders.reduce(
      (sum: number, order: RevenueOrder) =>
        sum + (recurringCustomerIds.has(order.userId) ? order.subtotal : 0),
      0,
    ),
  );

  const dailyMap = new Map<string, { revenue: number; orders: number }>();
  for (let index = 0; index < days; index += 1) {
    const date = new Date(periodStart);
    date.setUTCDate(date.getUTCDate() + index);
    dailyMap.set(date.toISOString().slice(0, 10), { revenue: 0, orders: 0 });
  }
  currentOrders.forEach((order: RevenueOrder) => {
    const key = order.createdAt.toISOString().slice(0, 10);
    const day = dailyMap.get(key);
    if (day) {
      day.revenue = roundMoney(day.revenue + order.subtotal);
      day.orders += 1;
    }
  });

  const products = new Map<string, { id: string; name: string; totalSold: number }>();
  soldItems.forEach((item) => {
    const existing = products.get(item.menuItemId);
    if (existing) {
      existing.totalSold += item.quantity;
    } else {
      products.set(item.menuItemId, {
        id: item.menuItemId,
        name: item.menuItem.name,
        totalSold: item.quantity,
      });
    }
  });
  const popularItems = [...products.values()]
    .sort((a, b) => b.totalSold - a.totalSold)
    .slice(0, 10);

  const cancellationRate = allCurrentOrders > 0
    ? Math.round((currentCancelledOrders / allCurrentOrders) * 1000) / 10
    : 0;
  const previousCancellationRate = previousAllOrders > 0
    ? Math.round((previousCancelledOrders / previousAllOrders) * 1000) / 10
    : 0;

  res.json({
    period: {
      days,
      start: periodStart.toISOString(),
      end: periodEnd.toISOString(),
      previousStart: previousStart.toISOString(),
      previousEnd: periodStart.toISOString(),
    },
    kpis: {
      revenue: currentRevenue,
      revenueDeltaPercent: percentageDelta(currentRevenue, previousRevenue),
      orders: currentOrders.length,
      averageBasket: currentOrders.length > 0
        ? roundMoney(currentRevenue / currentOrders.length)
        : 0,
      uniqueCustomers: currentCustomerIds.size,
      newCustomers,
      recurringCustomers: recurringCustomerIds.size,
      repurchaseRate: currentCustomerIds.size > 0
        ? Math.round((recurringCustomerIds.size / currentCustomerIds.size) * 1000) / 10
        : 0,
      recurringCustomerRevenue: recurringRevenue,
      cancelledOrders: currentCancelledOrders,
      cancellationRate,
    },
    previous: {
      revenue: previousRevenue,
      orders: previousOrders.length,
      averageBasket: previousOrders.length > 0
        ? roundMoney(previousRevenue / previousOrders.length)
        : 0,
      uniqueCustomers: previousCustomerIds.size,
      cancelledOrders: previousCancelledOrders,
      cancellationRate: previousCancellationRate,
    },
    comparison: {
      revenueDeltaPercent: percentageDelta(currentRevenue, previousRevenue),
      ordersDeltaPercent: percentageDelta(currentOrders.length, previousOrders.length),
      cancellationRateDeltaPoints: Math.round(
        (cancellationRate - previousCancellationRate) * 10,
      ) / 10,
    },
    daily: [...dailyMap.entries()].map(([date, values]) => ({ date, ...values })),
    popularItems,
  });
};

export const exportStats = async (req: Request, res: Response): Promise<void> => {
  const days = Number(req.query.period ?? 30);
  if (!Number.isInteger(days) || !ALLOWED_PERIODS.has(days)) {
    res.status(400).json({ error: 'La période doit être de 7, 30 ou 90 jours' });
    return;
  }

  const restaurant = await getRestaurantForOwner(req.user!.userId);
  if (!restaurant) {
    res.status(404).json({ error: 'Restaurant introuvable' });
    return;
  }

  const { periodStart, periodEnd } = buildPeriodRange(days);

  const orders = await prisma.order.findMany({
    where: {
      restaurantId: restaurant.id,
      status: 'COMPLETED',
      paymentStatus: 'PAID',
      createdAt: { gte: periodStart, lt: periodEnd },
    },
    select: { subtotal: true, createdAt: true },
  });

  const dailyMap = new Map<string, { revenue: number; orders: number }>();
  for (let index = 0; index < days; index += 1) {
    const date = new Date(periodStart);
    date.setUTCDate(date.getUTCDate() + index);
    dailyMap.set(date.toISOString().slice(0, 10), { revenue: 0, orders: 0 });
  }

  orders.forEach((order) => {
    const key = order.createdAt.toISOString().slice(0, 10);
    const day = dailyMap.get(key);
    if (day) {
      day.revenue = roundMoney(day.revenue + order.subtotal);
      day.orders += 1;
    }
  });

  const header = 'date,revenue,orders';
  const rows = [...dailyMap.entries()].map(
    ([date, values]) => `${date},${values.revenue.toFixed(2)},${values.orders}`,
  );
  const csv = [header, ...rows].join('\n');

  res.type('text/csv').send(csv);
};
