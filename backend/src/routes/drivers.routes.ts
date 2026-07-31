import { Router } from 'express';
import {
  getDriverProfile,
  replaceDriverSchedules,
  updateDriverAvailability,
} from '../controllers/drivers.controller';
import { authenticate, requireRole } from '../middleware/auth';

const router = Router();

router.use(authenticate, requireRole('LIVREUR'));
router.get('/me', getDriverProfile);
router.patch('/availability', updateDriverAvailability);
router.patch('/schedules', replaceDriverSchedules);

export default router;
