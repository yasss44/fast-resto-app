import { Router } from 'express';
import {
  createGroup,
  joinGroup,
  getMyGroups,
  getGroup,
  leaveGroup,
  lockGroup,
  submitGroup,
  updateMyGroupMember,
  updateMyPaymentStatus,
  saveGroupCart,
  getGroupCarts,
} from '../controllers/groups.controller';
import { authenticate } from '../middleware/auth';

const router = Router();

router.post('/', authenticate, createGroup);
router.post('/join', authenticate, joinGroup);
router.get('/mine', authenticate, getMyGroups);
router.get('/:id', authenticate, getGroup);
router.get('/:id/cart', authenticate, getGroupCarts);
router.put('/:id/cart', authenticate, saveGroupCart);
router.patch('/:id/member', authenticate, updateMyGroupMember);
router.patch('/:id/payment-status', authenticate, updateMyPaymentStatus);
router.patch('/:id/member/payment-status', authenticate, updateMyPaymentStatus);
router.post('/:id/lock', authenticate, lockGroup);
router.post('/:id/submit', authenticate, submitGroup);
router.post('/:id/leave', authenticate, leaveGroup);

export default router;
