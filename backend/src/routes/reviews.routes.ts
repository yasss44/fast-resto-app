import { Router } from 'express';
import { createReview, listReviews } from '../controllers/reviews.controller';
import { authenticate } from '../middleware/auth';

const router = Router();

// Public
router.get('/restaurant/:restaurantId', listReviews);

// Authenticated
router.post('/restaurant/:restaurantId', authenticate, createReview);

export default router;
