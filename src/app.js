import express from 'express';
import helmet from 'helmet';
import compression from 'compression';
import cookieParser from 'cookie-parser';
import cors from 'cors';
import pinoHttp from 'pino-http';
import { env } from './config/env.js';
import { logger } from './utils/logger.js';
import { errorHandler, notFoundHandler } from './middleware/errorHandler.js';
import healthRoutes from './routes/health.routes.js';
import catalogRoutes from './routes/catalog.routes.js';
import ordersRoutes from './routes/orders.routes.js';

const app = express();

app.use(helmet());
app.use(compression());
app.use(cors({ origin: env.CORS_ORIGIN || env.APP_URL, credentials: true }));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));
app.use(cookieParser());
app.use(pinoHttp({ logger }));

app.use('/api/v1', healthRoutes);
app.use('/api/v1', catalogRoutes);
app.use('/api/v1', ordersRoutes);

app.get('/', (req, res) => {
  res.json({
    success: true,
    message: 'NANAI Miel Orgánica API',
    version: '1.0.0',
  });
});

app.use(notFoundHandler);
app.use(errorHandler);

export default app;
