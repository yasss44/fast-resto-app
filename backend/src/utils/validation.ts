import { z } from 'zod';

// ─── Auth ───────────────────────────────────────────────────

const passwordSchema = z
  .string()
  .min(8, 'Minimum 8 caractères')
  .regex(/[A-Z]/, 'Doit contenir une majuscule')
  .regex(/[0-9]/, 'Doit contenir un chiffre');

export const registerSchema = z.object({
  email: z.string().email('Email invalide'),
  password: passwordSchema,
  name: z.string().min(1, 'Nom requis').max(100, 'Nom trop long'),
  phone: z.string().max(20, 'Téléphone trop long').optional(),
  role: z.enum(['CLIENT', 'RESTAURANT', 'LIVREUR']).default('CLIENT'),
  driverType: z.enum(['OCCASIONAL', 'PERMANENT']).optional(),
}).superRefine((data, ctx) => {
  if (data.role === 'LIVREUR' && !data.driverType) {
    ctx.addIssue({
      code: z.ZodIssueCode.custom,
      path: ['driverType'],
      message: 'Type de livreur requis',
    });
  }
});

export const loginSchema = z.object({
  email: z.string().email('Email invalide'),
  password: z.string().min(1, 'Mot de passe requis'),
});

export const updateProfileSchema = z.object({
  name: z.string().min(1, 'Nom requis').max(100, 'Nom trop long').optional(),
  phone: z.string().max(20, 'Téléphone trop long').optional(),
});

// ─── Restaurant ─────────────────────────────────────────────

export const createRestaurantSchema = z.object({
  name: z.string().min(1, 'Nom requis').max(200, 'Nom trop long'),
  description: z.string().max(2000, 'Description trop longue').optional(),
  category: z.string().max(50).optional(),
  address: z.string().max(500).optional(),
  city: z.string().max(100).optional(),
  cuisineType: z.string().max(100).optional(),
  image: z.string().optional(),
  managerIban: z.string().optional(),
  normalPrepTime: z.number().int().min(5).max(60).default(15),
  rushPrepTime: z.number().int().min(10).max(90).default(25),
  dietaryOptions: z.array(z.nativeEnum({ VEGAN: 'VEGAN', VEGETARIAN: 'VEGETARIAN', GLUTEN_FREE: 'GLUTEN_FREE', HALAL: 'HALAL', KETO: 'KETO', DAIRY_FREE: 'DAIRY_FREE' })).optional(),
});

export const updateRestaurantSchema = createRestaurantSchema.partial().extend({
  latitude: z.number().min(-90).max(90).optional(),
  longitude: z.number().min(-180).max(180).optional(),
  deliveryEnabled: z.boolean().optional(),
  deliveryFee: z.number().min(0).max(50).optional(),
  deliveryRadiusKm: z.number().min(0.5).max(50).optional(),
});

// ─── Order tracking / pickup ─────────────────────────────────

export const updateOrderTrackingSchema = z.object({
  gpsProgress: z.number().min(0).max(1).optional(),
  isReadyAtEntrance: z.boolean().optional(),
}).refine((data) => data.gpsProgress !== undefined || data.isReadyAtEntrance !== undefined, {
  message: 'Au moins un champ requis (gpsProgress ou isReadyAtEntrance)',
});

export const verifyPickupSchema = z.object({
  token: z.string().min(1, 'Token requis'),
});

// ─── Menu ───────────────────────────────────────────────────

export const createMenuItemSchema = z.object({
  name: z.string().min(1, 'Nom requis').max(200, 'Nom trop long'),
  description: z.string().max(2000).optional(),
  price: z.number().positive('Prix doit être positif').max(9999.99, 'Prix trop élevé'),
  image: z.string().max(500).optional(),
  category: z.string().max(50).optional(),
  dietaryTags: z.array(z.nativeEnum({ VEGAN: 'VEGAN', VEGETARIAN: 'VEGETARIAN', GLUTEN_FREE: 'GLUTEN_FREE', HALAL: 'HALAL', KETO: 'KETO', DAIRY_FREE: 'DAIRY_FREE' })).optional(),
});

export const updateMenuItemSchema = createMenuItemSchema.extend({
  isAvailable: z.boolean().optional(),
}).partial();

// ─── Order ──────────────────────────────────────────────────

export const cartItemSchema = z.object({
  menuItemId: z.string(),
  quantity: z.number().int().positive().max(99, 'Quantité max: 99'),
  selectedOptions: z.array(z.string()).max(20).optional(),
  allergyNotes: z.string().max(500, 'Notes trop longues').optional(),
});

export const placeOrderSchema = z.object({
  restaurantId: z.string(),
  items: z.array(cartItemSchema).min(1, 'Au moins un article').max(50, 'Maximum 50 articles'),
  userWalkTimeMin: z.number().int().min(1).max(120).default(10),
  groupId: z.string().optional(),
  fulfillmentType: z.enum(['PICKUP', 'DELIVERY']).default('PICKUP'),
  deliveryAddress: z.string().max(500).optional(),
  deliveryLatitude: z.number().min(-90).max(90).optional(),
  deliveryLongitude: z.number().min(-180).max(180).optional(),
}).superRefine((data, ctx) => {
  if (data.fulfillmentType === 'DELIVERY') {
    if (!data.deliveryAddress?.trim()) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['deliveryAddress'],
        message: 'Adresse de livraison requise',
      });
    }
    if (data.groupId) {
      ctx.addIssue({
        code: z.ZodIssueCode.custom,
        path: ['groupId'],
        message: 'La livraison n\'est pas disponible pour les commandes groupées',
      });
    }
  }
});

export const updateOrderStatusSchema = z.object({
  status: z.enum(['PLACED', 'PREPARING', 'READY_FOR_PICKUP', 'COMPLETED', 'CANCELLED']),
  isBilledAnyway: z.boolean().optional(),
});

// ─── Review ─────────────────────────────────────────────────

export const createReviewSchema = z.object({
  rating: z.number().min(1).max(5),
  comment: z.string().max(2000, 'Commentaire trop long').optional(),
  orderId: z.string().optional(),
});

// ─── Notification ───────────────────────────────────────────

export const createNotificationSchema = z.object({
  title: z.string().min(1).max(200),
  body: z.string().min(1).max(2000),
  type: z.enum(['STATUS', 'INFO', 'SUCCESS', 'RATING']).default('INFO'),
});

// ─── Group Orders ───────────────────────────────────────────

export const createGroupSchema = z.object({
  restaurantId: z.string().min(1, 'Restaurant requis'),
});

export const joinGroupSchema = z.object({
  code: z.string().min(1, 'Code requis').max(20),
});

export const updateGroupMemberSchema = z.object({
  itemsCount: z.number().int().min(0).max(99),
  total: z.number().min(0).max(9999.99),
  isReady: z.boolean(),
});

export const saveGroupCartSchema = z.object({
  items: z.array(cartItemSchema).max(50, 'Maximum 50 articles'),
});

// ─── Deliveries / Livreur ───────────────────────────────────

export const acceptDeliverySchema = z.object({
  // No body expected — status is set server-side to 'ACCEPTED'
});

export const updateDeliveryStatusSchema = z.object({
  status: z.enum(['AT_RESTAURANT', 'PICKED_UP', 'DELIVERED', 'CANCELLED']),
});

export const updateDriverAvailabilitySchema = z.object({
  isOnline: z.boolean().optional(),
  isPaused: z.boolean().optional(),
});

export const replaceDriverSchedulesSchema = z.object({
  timezone: z.string().min(1).max(100).default('Europe/Paris'),
  schedules: z.array(z.object({
    dayOfWeek: z.number().int().min(1).max(7),
    startMinute: z.number().int().min(0).max(1439),
    endMinute: z.number().int().min(1).max(1440),
    isEnabled: z.boolean().default(true),
  }).refine((slot) => slot.endMinute > slot.startMinute, {
    message: 'La fin du créneau doit être après le début',
  })).max(21),
});

