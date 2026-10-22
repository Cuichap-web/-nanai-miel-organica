import { env } from '../config/env.js';
import { logger } from '../utils/logger.js';

export function errorHandler(err, req, res, next) {
  const statusCode = err.statusCode || 500;
  const code = err.code || 'INTERNAL_ERROR';
  const isDev = env.NODE_ENV === 'development';

  if (statusCode >= 500) {
    logger.error(
      {
        err: err.message,
        stack: err.stack,
        code,
        method: req.method,
        url: req.originalUrl,
      },
      'Error no controlado'
    );
  } else {
    logger.warn({ code, method: req.method, url: req.originalUrl, err: err.message }, 'Error de cliente');
  }

  res.status(statusCode).json({
    success: false,
    error: {
      code,
      message: err.isOperational || isDev ? err.message : 'Error interno del servidor',
      ...(err.details ? { details: err.details } : {}),
      ...(isDev && err.stack ? { stack: err.stack } : {}),
    },
  });
}

export function notFoundHandler(req, res) {
  res.status(404).json({
    success: false,
    error: {
      code: 'ROUTE_NOT_FOUND',
      message: `Ruta no encontrada: ${req.method} ${req.originalUrl}`,
    },
  });
}

export default errorHandler;
