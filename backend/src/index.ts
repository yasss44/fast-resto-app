import http from 'http';
import app from './app';
import { env } from './config/env';
import { prisma } from './services/prisma';
import { initRealtime } from './services/realtime';

async function main() {
  // Test DB connection
  try {
    await prisma.$connect();
    console.log('[DB] Connecté à PostgreSQL');
  } catch (error) {
    console.error('[DB] Échec de connexion:', error);
    process.exit(1);
  }

  const server = http.createServer(app);
  initRealtime(server);

  server.listen(env.port, () => {
    console.log(`[Server] FAST API en écoute sur http://localhost:${env.port}`);
    console.log(`[Server] WebSocket (Socket.IO) actif sur le même port`);
    console.log(`[Server] Environnement: ${env.nodeEnv}`);
  });
}

main().catch((err) => {
  console.error('[Fatal]', err);
  process.exit(1);
});
