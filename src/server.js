import app from './app.js';
import { env } from './config/env.js';
import { testConnection } from './config/db.js';
import { logger } from './utils/logger.js';

async function start() {
  const dbOk = await testConnection();
  if (!dbOk && env.NODE_ENV === 'production') {
    logger.error('No se pudo conectar a la base de datos. Saliendo...');
    process.exit(1);
  }

  app.listen(env.PORT, () => {
    logger.info(`🚀 Servidor corriendo en http://localhost:${env.PORT}`);
    logger.info(`📦 Entorno: ${env.NODE_ENV}`);
  });
}

start();
