import { randomBytes } from 'crypto';

export function generatePickupToken(): string {
  return `FAST-${randomBytes(16).toString('hex')}`;
}
