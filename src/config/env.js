import { z } from 'zod';
import dotenv from 'dotenv';

dotenv.config();

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().default(3000),
  APP_URL: z.string().url(),
  DB_HOST: z.string().default('127.0.0.1'),
  DB_PORT: z.coerce.number().default(3306),
  DB_USER: z.string().min(1),
  DB_PASSWORD: z.string().min(1),
  DB_NAME: z.string().min(1),
  SESSION_SECRET: z.string().min(32, 'SESSION_SECRET debe tener al menos 32 caracteres'),
  SESSION_NAME: z.string().default('nanai.sid'),
  RESERVA_TTL_MINUTOS: z.coerce.number().default(30),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  RATE_LIMIT_WINDOW_MS: z.coerce.number().default(900000),
  RATE_LIMIT_MAX: z.coerce.number().default(100),
  PAGOS_PROVEEDOR: z.enum(['test', 'culqi', 'izipay', 'manual']).default('test'),
  PAGOS_API_KEY: z.string().optional(),
  PAGOS_WEBHOOK_SECRET: z.string().optional(),
  PAGOS_VERIFICACION_CRUZADA: z.coerce.boolean().default(false),
  DNI_PROVEEDOR: z.string().optional(),
  DNI_API_KEY: z.string().optional(),
  MAIL_HOST: z.string().optional(),
  MAIL_PORT: z.coerce.number().optional(),
  MAIL_USER: z.string().optional(),
  MAIL_PASS: z.string().optional(),
  MAIL_FROM: z.string().email().optional(),
  STORAGE_TYPE: z.enum(['local', 'cloud']).default('local'),
  STORAGE_PATH: z.string().default('./storage'),
  TRUST_PROXY: z.coerce.boolean().default(false),
  CORS_ORIGIN: z.string().url().optional(),
  ARGON2_OPTIONS: z.string().optional(),
});

const parsed = envSchema.safeParse(process.env);

if (!parsed.success) {
  console.error('✖ Error de configuración:');
  parsed.error.errors.forEach((err) => {
    console.error(`  - ${err.path.join('.')}: ${err.message}`);
  });
  console.error('\nVer docs/08-instalacion.md');
  process.exit(1);
}

export const env = parsed.data;
export default env;
