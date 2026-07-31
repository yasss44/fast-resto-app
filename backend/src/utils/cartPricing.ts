import { prisma } from '../services/prisma';

export type CartItemInput = {
  menuItemId: string;
  quantity: number;
  selectedOptions?: string[];
  allergyNotes?: string;
};

export type PricedCartItem = CartItemInput & {
  unitPrice: number;
  lineTotal: number;
  menuItemName: string;
};

export async function computeCartPricing(
  restaurantId: string,
  items: CartItemInput[],
): Promise<{ items: PricedCartItem[]; subtotal: number; itemsCount: number }> {
  const menuItemIds = [...new Set(items.map((i) => i.menuItemId))];
  const menuItems = await prisma.menuItem.findMany({
    where: { id: { in: menuItemIds }, restaurantId },
    include: { supplements: true },
  });

  if (menuItems.length !== menuItemIds.length) {
    throw new Error('MENU_ITEMS_NOT_FOUND');
  }

  const unavailable = menuItems.filter((m) => !m.isAvailable);
  if (unavailable.length > 0) {
    throw new Error('MENU_ITEMS_UNAVAILABLE');
  }

  const menuItemMap = new Map(menuItems.map((m) => [m.id, m]));
  let subtotal = 0;
  let itemsCount = 0;

  const pricedItems: PricedCartItem[] = items.map((item) => {
    const menuItem = menuItemMap.get(item.menuItemId)!;
    const supplementMap = new Map(menuItem.supplements.map((s) => [s.id, s]));
    const selectedOptions = item.selectedOptions || [];

    let supplementTotal = 0;
    for (const optId of selectedOptions) {
      const supplement = supplementMap.get(optId);
      if (!supplement) {
        throw new Error('SUPPLEMENT_NOT_FOUND');
      }
      supplementTotal += supplement.price;
    }

    const unitPrice = menuItem.price + supplementTotal;
    const lineTotal = unitPrice * item.quantity;
    subtotal += lineTotal;
    itemsCount += item.quantity;

    return {
      ...item,
      unitPrice,
      lineTotal,
      menuItemName: menuItem.name,
    };
  });

  return {
    items: pricedItems,
    subtotal: Math.round(subtotal * 100) / 100,
    itemsCount,
  };
}
