import { Router } from 'express';
import {
  listRestaurants,
  getRestaurant,
  createRestaurant,
  updateRestaurant,
  getMyRestaurant,
  toggleRushMode,
} from '../controllers/restaurants.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

// Public
router.get('/', listRestaurants);
router.get('/:id', getRestaurant);

// Restaurant owner
router.get('/account/mine', authenticate, requireRole('RESTAURANT'), getMyRestaurant);
router.post('/', authenticate, requireRole('RESTAURANT'), createRestaurant);
router.patch('/:id', authenticate, requireRole('RESTAURANT'), updateRestaurant);
router.post('/toggle-rush', authenticate, requireRole('RESTAURANT'), toggleRushMode);

export default router;
