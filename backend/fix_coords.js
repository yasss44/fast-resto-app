const { PrismaClient } = require('@prisma/client');
const prisma = new PrismaClient();
async function main() {
  await prisma.restaurant.updateMany({
    where: { latitude: 48.8566, longitude: 2.3476 },
    data: { latitude: 48.8614, longitude: 2.3438 }
  });
  console.log('Fixed river restaurant coordinates!');
}
main().finally(() => prisma.$disconnect());
