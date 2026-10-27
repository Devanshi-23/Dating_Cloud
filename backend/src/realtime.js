import jwt from 'jsonwebtoken';
import { Server } from 'socket.io';
import { config } from './config.js';
import { emitToUsers, setRealtimeSink } from './realtime-hub.js';
import { markMessagesRead, participantConversation, store } from './routes.js';

const typingAt = new Map();

function ack(callback, body) {
  if (typeof callback === 'function') callback(body);
}

export function attachRealtime(httpServer) {
  const io = new Server(httpServer, {
    cors: { origin: true },
    transports: ['websocket'],
  });
  const nsp = io.of('/v1');
  setRealtimeSink((userId, event, payload) => {
    nsp.to(`user:${userId}`).emit(event, payload);
  });

  nsp.use((socket, next) => {
    try {
      const payload = jwt.verify(socket.handshake.auth?.token, config.jwtAccessSecret);
      if (payload.typ !== 'access' || !store.users.has(payload.sub)) {
        const error = new Error('UNAUTHENTICATED');
        error.data = { code: 'UNAUTHENTICATED' };
        return next(error);
      }
      socket.data.userId = payload.sub;
      socket.data.exp = payload.exp;
      return next();
    } catch {
      const error = new Error('UNAUTHENTICATED');
      error.data = { code: 'UNAUTHENTICATED' };
      return next(error);
    }
  });

  nsp.on('connection', (socket) => {
    const userId = socket.data.userId;
    socket.join(`user:${userId}`);
    const delay = Math.max(0, socket.data.exp * 1000 - Date.now());
    const timer = setTimeout(() => {
      socket.emit('session:expired', { code: 'UNAUTHENTICATED' });
      socket.disconnect(true);
    }, delay);
    socket.on('disconnect', () => clearTimeout(timer));

    socket.on('typing', (payload, callback) => {
      const conversation = participantConversation(userId, payload?.conversationId);
      if (!conversation) {
        ack(callback, {
          ok: false,
          error: {
            code: 'MATCH_REQUIRED',
            message: 'You can message someone after you match.',
          },
        });
        return;
      }
      const isTyping = payload?.isTyping === true;
      const key = `${userId}:${conversation.id}`;
      const now = Date.now();
      if (isTyping && now - (typingAt.get(key) ?? 0) < 3000) {
        ack(callback, {
          ok: false,
          error: {
            code: 'RATE_LIMITED',
            message: 'Too many attempts. Please wait and try again.',
          },
        });
        return;
      }
      if (isTyping) typingAt.set(key, now);
      const otherId = conversation.userIds.find((id) => id !== userId);
      if (otherId) {
        emitToUsers([otherId], 'typing', {
          conversationId: conversation.id,
          userId,
          isTyping,
        });
      }
      ack(callback, { ok: true });
    });

    socket.on('message:read', (payload, callback) => {
      const message = store.messages.find(
        (item) =>
          item.id === payload?.upToMessageId &&
          item.conversationId === payload?.conversationId,
      );
      if (!message || !markMessagesRead(userId, message)) {
        ack(callback, {
          ok: false,
          error: {
            code: 'NOT_FOUND',
            message: 'We could not find what you were looking for.',
          },
        });
        return;
      }
      ack(callback, { ok: true });
    });
  });

  return io;
}
