import dotenv from 'dotenv';

dotenv.config();

function requireEnv(key: string): string {
  const val = process.env[key];
  if (!val) {
    throw new Error(`Missing required environment variable: ${key}`);
  }
  return val;
}

export const env = {
  port: parseInt(process.env.PORT || '3000', 10),
  nodeEnv: process.env.NODE_ENV || 'development',
  databaseUrl: process.env.DATABASE_URL || '',
  jwtSecret: requireEnv('JWT_SECRET'),
  jwtExpiresIn: process.env.JWT_EXPIRES_IN || '24h',
  corsOrigin: process.env.CORS_ORIGIN || 'http://localhost:3000,http://localhost:5173',
  uploadDir: process.env.UPLOAD_DIR || './uploads',
  serviceFee: parseFloat(process.env.SERVICE_FEE || '1.50'),
  bcryptRounds: parseInt(process.env.BCRYPT_ROUNDS || '12', 10),
  maxFailedLogins: parseInt(process.env.MAX_FAILED_LOGINS || '5', 10),
  lockoutMinutes: parseInt(process.env.LOCKOUT_MINUTES || '15', 10),
  mistralApiKey: requireEnv('MISTRAL_API_KEY'),
  stripeSecretKey: process.env.STRIPE_SECRET_KEY || '',
  stripeWebhookSecret: process.env.STRIPE_WEBHOOK_SECRET || '',
  stripeCurrency: process.env.STRIPE_CURRENCY || 'eur',
  stripeSuccessUrl: process.env.STRIPE_SUCCESS_URL || 'https://backend-lovat-xi-0axv990rct.vercel.app/api/payments/checkout/success?session_id={CHECKOUT_SESSION_ID}',
  stripeCancelUrl: process.env.STRIPE_CANCEL_URL || 'https://backend-lovat-xi-0axv990rct.vercel.app/api/payments/checkout/cancel',
};
