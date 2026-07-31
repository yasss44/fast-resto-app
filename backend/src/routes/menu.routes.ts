import { Router } from 'express';
import { listMenuItems, createMenuItem, updateMenuItem, deleteMenuItem, scanMenu, addSupplement, updateSupplement, deleteSupplement } from '../controllers/menu.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

// Public
router.get('/restaurant/:restaurantId', listMenuItems);

// Restaurant owner
router.post('/restaurant/:restaurantId/scan', authenticate, requireRole('RESTAURANT'), scanMenu);
router.post('/restaurant/:restaurantId', authenticate, requireRole('RESTAURANT'), createMenuItem);
router.patch('/:id', authenticate, requireRole('RESTAURANT'), updateMenuItem);
router.delete('/:id', authenticate, requireRole('RESTAURANT'), deleteMenuItem);

// Supplements
router.post('/:menuItemId/supplements', authenticate, requireRole('RESTAURANT'), addSupplement);
router.patch('/supplements/:id', authenticate, requireRole('RESTAURANT'), updateSupplement);
router.delete('/supplements/:id', authenticate, requireRole('RESTAURANT'), deleteSupplement);

export default router;
