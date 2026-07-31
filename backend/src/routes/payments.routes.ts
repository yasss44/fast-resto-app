import { Router } from 'express';
import {
  checkoutCancelPage,
  checkoutSuccessPage,
  confirmCheckoutSession,
  createCheckoutSession,
  createConnectAccountLink,
  getConnectStatus,
} from '../controllers/payments.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.get('/checkout/success', checkoutSuccessPage);
router.get('/checkout/cancel', checkoutCancelPage);
router.post('/checkout-session', authenticate, createCheckoutSession);
router.post('/checkout-session/:sessionId/confirm', authenticate, confirmCheckoutSession);

router.post('/connect/account-link', authenticate, requireRole('RESTAURANT'), createConnectAccountLink);
router.get('/connect/status', authenticate, requireRole('RESTAURANT'), getConnectStatus);

export default router;
