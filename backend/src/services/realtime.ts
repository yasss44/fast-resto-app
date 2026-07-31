import { Server as HttpServer } from 'http';
import { Server, Socket } from 'socket.io';
import jwt from 'jsonwebtoken';
import { env } from '../config/env';
import { prisma } from './prisma';

interface AuthPayload {
  userId: string;
  role: string;
  tokenVersion: number;
}

let io: Server | null = null;

export function initRealtime(httpServer: HttpServer): Server {
  io = new Server(httpServer, {
    cors: {
      origin: env.corsOrigin.split(',').map((s) => s.trim()),
      credentials: true,
    },
    pingInterval: 25000,
    pingTimeout: 20000,
  });

  io.use(async (socket: Socket, next) => {
    const token = socket.handshake.auth?.token as string | undefined;
    if (!token) {
      return next(new Error('Authentication required'));
    }
    try {
      const decoded = jwt.verify(token, env.jwtSecret) as AuthPayload;
      const user = await prisma.user.findUnique({
        where: { id: decoded.userId },
        select: { tokenVersion: true },
      });
      if (!user || user.tokenVersion !== decoded.tokenVersion) {
        return next(new Error('Session expired'));
      }
      (socket as Socket & { user: AuthPayload }).user = decoded;
      next();
    } catch {
      next(new Error('Invalid token'));
    }
  });

  io.on('connection', (socket: Socket) => {
    const authedSocket = socket as Socket & { user: AuthPayload };
    console.log(`[WS] Client connecté: ${socket.id} (user: ${authedSocket.user.userId})`);

    socket.on('join:user', (userId: string) => {
      if (userId !== authedSocket.user.userId) {
        socket.emit('error', 'Unauthorized room');
        return;
      }
      socket.join(`user:${userId}`);
      console.log(`[WS] ${socket.id} → joined user:${userId}`);
    });

    socket.on('join:restaurant', async (restaurantId: string) => {
      if (authedSocket.user.role !== 'RESTAURANT') {
        socket.emit('error', 'Unauthorized room');
        return;
      }
      const restaurant = await prisma.restaurant.findFirst({
        where: { id: restaurantId, ownerId: authedSocket.user.userId },
        select: { id: true },
      });
      if (!restaurant) {
        socket.emit('error', 'Unauthorized room');
        return;
      }
      socket.join(`restaurant:${restaurantId}`);
      console.log(`[WS] ${socket.id} → joined restaurant:${restaurantId}`);
    });

    socket.on('disconnect', () => {
      console.log(`[WS] Client déconnecté: ${socket.id}`);
    });
  });

  console.log('[WS] Socket.IO initialisé');
  return io;
}

export function getIO(): Server | null {
  return io;
}

export function emitToUser(userId: string, event: string, data: unknown): void {
  if (!io) return;
  io.to(`user:${userId}`).emit(event, data);
}

export function emitToRestaurant(restaurantId: string, event: string, data: unknown): void {
  if (!io) return;
  io.to(`restaurant:${restaurantId}`).emit(event, data);
}

export function safeEmitOrderToRestaurant(restaurantId: string, order: unknown): void {
  if (!io) return;
  io.to(`restaurant:${restaurantId}`).emit('order:new', order);
}

export function safeEmitOrderStatusToUser(
  userId: string,
  data: { orderId: string; status: string; [key: string]: unknown },
): void {
  if (!io) return;
  io.to(`user:${userId}`).emit('order:status', data);
}

export function safeEmitNotificationToUser(userId: string, notification: unknown): void {
  if (!io) return;
  io.to(`user:${userId}`).emit('notification', notification);
}

export function emitOrderUpdate(userId: string, order: unknown): void {
  if (!io) return;
  io.to(`user:${userId}`).emit('order:update', order);
}

export function emitOrderToRestaurant(restaurantId: string, order: unknown): void {
  safeEmitOrderToRestaurant(restaurantId, order);
}

export function emitOrderStatusToUser(
  userId: string,
  data: { orderId: string; status: string; [key: string]: unknown },
): void {
  safeEmitOrderStatusToUser(userId, data);
}

export function emitNotificationToUser(userId: string, notification: unknown): void {
  safeEmitNotificationToUser(userId, notification);
}
