import cors from 'cors';
import express from 'express';
import { fail, requestId } from './http.js';
import { registerRoutes } from './routes.js';

export function createApp() {
  const app = express();
  app.disable('x-powered-by');
  app.use(cors());
  app.use((req, res, next) => {
    res.locals.requestId = requestId();
    next();
  });
  app.use(express.json({ limit: '1mb' }));
  registerRoutes(app);
  app.use((_req, res) => {
    fail(res, 'NOT_FOUND', 'We could not find what you were looking for.');
  });
  return app;
}
