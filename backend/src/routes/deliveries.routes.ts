import { Router } from 'express';
import {
  getAvailableDeliveries,
  acceptDelivery,
  updateDeliveryStatus,
  getMyActiveDelivery,
  getOrderDeliveryForClient,
} from '../controllers/deliveries.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.get('/order/:orderId', authenticate, getOrderDeliveryForClient);

// Only eligible drivers can view or manage delivery opportunities.
router.get('/available', authenticate, requireRole('LIVREUR'), getAvailableDeliveries);
router.get('/active', authenticate, requireRole('LIVREUR'), getMyActiveDelivery);
router.post('/:id/accept', authenticate, requireRole('LIVREUR'), acceptDelivery);
router.patch('/:id/status', authenticate, requireRole('LIVREUR'), updateDeliveryStatus);

export default router;
