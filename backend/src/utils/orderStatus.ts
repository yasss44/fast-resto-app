import { OrderStatus } from '@prisma/client';

const VALID_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  PLACED: ['PREPARING', 'CANCELLED'],
  PREPARING: ['READY_FOR_PICKUP', 'CANCELLED'],
  READY_FOR_PICKUP: ['COMPLETED', 'CANCELLED'],
  COMPLETED: [],
  CANCELLED: [],
};

export function isValidStatusTransition(from: OrderStatus, to: OrderStatus): boolean {
  if (from === to) return true;
  return VALID_TRANSITIONS[from]?.includes(to) ?? false;
}

export const STATUS_LABELS: Record<string, string> = {
  PREPARING: 'Préparation commencée',
  READY_FOR_PICKUP: 'Repas prêt !',
  COMPLETED: 'Commande récupérée',
  CANCELLED: 'Commande annulée',
};
