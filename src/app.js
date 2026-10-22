import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import pinoHttp from 'pino-http';
import path from 'path';
import { fileURLToPath } from 'url';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import { sessionMiddleware } from './config/session.js';
import { attachUser } from './middleware/auth.js';
import healthRoutes from './routes/health.routes.js';
import catalogRoutes from './routes/catalog.routes.js';
import ordersRoutes from './routes/orders.routes.js';
import authRoutes from './routes/auth.routes.js';
import adminRoutes from './routes/admin.routes.js';
import posRoutes from './routes/pos.routes.js';
import pagosRoutes from './routes/pagos.routes.js';
import pagosWebhookRoutes from './routes/pagos.webhook.routes.js';
import jobsRoutes from './routes/jobs.routes.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();

app.use(helmet());
app.use(compression());
app.use(cors({ origin: env.CORS_ORIGIN || env.APP_URL, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(pinoHttp({ logger }));
app.use(sessionMiddleware);
app.use(attachUser);

app.use(express.static(path.join(__dirname, '../public')));

app.use('/api/v1', healthRoutes);
app.use('/api/v1', catalogRoutes);
app.use('/api/v1', ordersRoutes);
app.use('/api/v1/auth', authRoutes);
app.use('/api/v1/admin', adminRoutes);
app.use('/api/v1', posRoutes);
app.use('/api/v1', pagosRoutes);
app.use('/api/v1', pagosWebhookRoutes);
app.use('/api/v1', jobsRoutes);

app.get('/', (req, res) => {
  res.sendFile(path.join(__dirname, '../public/index.html'));
});

app.use(notFoundHandler);
app.use(errorHandler);

export default app;
