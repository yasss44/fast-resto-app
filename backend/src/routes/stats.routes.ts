import { Router } from 'express';
import { getStats, exportStats } from '../controllers/stats.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.get('/export', authenticate, requireRole('RESTAURANT'), exportStats);
router.get('/', authenticate, requireRole('RESTAURANT'), getStats);

export default router;
