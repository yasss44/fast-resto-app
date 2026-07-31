import { Router } from 'express';
import {
  placeOrder,
  getOrder,
  getMyOrders,
  getRestaurantOrders,
  updateOrderStatus,
  updateOrderTracking,
  verifyPickup,
  cancelMyOrder,
} from '../controllers/orders.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

// Client
router.post('/', authenticate, placeOrder);
router.get('/mine', authenticate, getMyOrders);
router.post('/:id/cancel', authenticate, cancelMyOrder);

// Restaurant (before /:id to avoid conflict)
router.get('/restaurant', authenticate, requireRole('RESTAURANT'), getRestaurantOrders);
router.patch('/:id/status', authenticate, requireRole('RESTAURANT'), updateOrderStatus);
router.post('/:id/verify-pickup', authenticate, requireRole('RESTAURANT'), verifyPickup);

// Shared / client detail
router.get('/:id', authenticate, getOrder);
router.patch('/:id/tracking', authenticate, updateOrderTracking);

export default router;
