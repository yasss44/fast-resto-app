import { PrismaClient, DietaryOption } from '@prisma/client';
import bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

async function main() {
  console.log('Seeding database...');

  await prisma.notification.deleteMany();
  await prisma.review.deleteMany();
  await prisma.cartItem.deleteMany();
  await prisma.paymentCheckout.deleteMany();
  await prisma.order.deleteMany();
  await prisma.groupMember.deleteMany();
  await prisma.groupOrder.deleteMany();
  await prisma.menuItemSupplement.deleteMany();
  await prisma.menuItemDietaryOption.deleteMany();
  await prisma.menuItem.deleteMany();
  await prisma.restaurantDietaryOption.deleteMany();
  await prisma.restaurant.deleteMany();
  await prisma.user.deleteMany();

  const clientPassword = await bcrypt.hash('client123', 12);
  const restoPassword = await bcrypt.hash('resto123', 12);

  const client = await prisma.user.create({
    data: { email: 'client@fast.app', password: clientPassword, name: 'Alex Client', phone: '0612345678', role: 'CLIENT', points: 40 },
  });

  const restoOwner1 = await prisma.user.create({
    data: { email: 'resto@fast.app', password: restoPassword, name: 'Karim Restaurant', phone: '0698765432', role: 'RESTAURANT' },
  });

  const restoOwner2 = await prisma.user.create({
    data: { email: 'resto2@fast.app', password: restoPassword, name: 'Sofia Restaurant', phone: '0611111111', role: 'RESTAURANT' },
  });

  const rest1 = await prisma.restaurant.create({
    data: {
      ownerId: restoOwner1.id,
      name: 'The Velvet Burger Co.',
      description: 'Burgers artisanaux de qualité supérieure grillés à la flamme.',
      image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=800&q=80',
      logo: 'https://images.unsplash.com/photo-1550547660-d9450f859349?auto=format&fit=crop&w=200&q=80',
      category: 'burger',
      address: '742 Evergreen Terrace, Centre-ville',
      city: 'Paris',
      cuisineType: 'Burger',
      rating: 4.8,
      pickupPrepTime: 12,
      normalPrepTime: 12,
      rushPrepTime: 20,
      distance: 1.2,
      latitude: 48.8614,
      longitude: 2.3438,
      dietaryOptions: {
        create: [{ option: DietaryOption.HALAL }, { option: DietaryOption.GLUTEN_FREE }],
      },
    },
  });

  const rest2 = await prisma.restaurant.create({
    data: {
      ownerId: restoOwner2.id,
      name: 'Napoli Forno & Trattoria',
      description: 'Authentiques pizzas napolitaines cuites au feu de bois.',
      image: 'https://images.unsplash.com/photo-1513104890138-7c749659a591?auto=format&fit=crop&w=800&q=80',
      logo: 'https://images.unsplash.com/photo-1534308983496-4fabb1a015ee?auto=format&fit=crop&w=200&q=80',
      category: 'pizza',
      address: '12 Corso di Roma, Little Italy',
      city: 'Paris',
      cuisineType: 'Italien',
      rating: 4.7,
      pickupPrepTime: 15,
      normalPrepTime: 15,
      rushPrepTime: 25,
      distance: 2.4,
      latitude: 48.8584,
      longitude: 2.3458,
      dietaryOptions: {
        create: [{ option: DietaryOption.VEGETARIAN }, { option: DietaryOption.VEGAN }],
      },
    },
  });

  await prisma.menuItem.create({
    data: {
      restaurantId: rest1.id,
      name: 'Double Velvet Deluxe',
      description: 'Deux steaks de bœuf, double cheddar fumé, sauce secrète maison.',
      price: 12.99,
      image: 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&w=400&q=80',
      category: 'burger',
      rating: 4.9,
      dietaryTags: { create: [{ option: DietaryOption.HALAL }] },
    },
  });

  await prisma.menuItem.create({
    data: {
      restaurantId: rest1.id,
      name: 'Beyond Smash sans Gluten',
      description: 'Steak végétal Beyond Meat, pain brioché sans gluten.',
      price: 14.50,
      image: 'https://images.unsplash.com/photo-1586190848861-99aa4a171e90?auto=format&fit=crop&w=400&q=80',
      category: 'burger',
      rating: 4.7,
      dietaryTags: {
        create: [
          { option: DietaryOption.VEGETARIAN },
          { option: DietaryOption.VEGAN },
          { option: DietaryOption.GLUTEN_FREE },
        ],
      },
    },
  });

  await prisma.menuItem.create({
    data: {
      restaurantId: rest1.id,
      name: 'Frites Maison au Parmesan',
      description: 'Frites fraîches, huile de truffe blanche, parmesan affiné.',
      price: 5.99,
      image: 'https://images.unsplash.com/photo-1576107232684-1279f390859f?auto=format&fit=crop&w=400&q=80',
      category: 'burger',
      dietaryTags: { create: [{ option: DietaryOption.VEGETARIAN }] },
    },
  });

  await prisma.menuItem.create({
    data: {
      restaurantId: rest2.id,
      name: 'Regina Margherita D.O.C.',
      description: 'Tomates San Marzano, mozzarella de bufflonne, basilic frais.',
      price: 13.99,
      image: 'https://images.unsplash.com/photo-1604068549290-dea0e4a305ca?auto=format&fit=crop&w=400&q=80',
      category: 'pizza',
      rating: 4.8,
      dietaryTags: { create: [{ option: DietaryOption.VEGETARIAN }] },
    },
  });

  await prisma.menuItem.create({
    data: {
      restaurantId: rest2.id,
      name: 'Vegan Marinara Rustica',
      description: 'Tomates concassées, ail sauvage, origan de Sicile.',
      price: 11.50,
      image: 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002?auto=format&fit=crop&w=400&q=80',
      category: 'pizza',
      dietaryTags: {
        create: [
          { option: DietaryOption.VEGETARIAN },
          { option: DietaryOption.VEGAN },
          { option: DietaryOption.DAIRY_FREE },
        ],
      },
    },
  });

  void client;
  console.log('Seed completed successfully!');
  console.log('  Restaurants linked to owners:');
  console.log(`    ${rest1.name} → resto@fast.app`);
  console.log(`    ${rest2.name} → resto2@fast.app`);
  console.log('  Client: client@fast.app / client123');
  console.log('  Resto:  resto@fast.app / resto123');
  console.log('  Resto2: resto2@fast.app / resto123');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
