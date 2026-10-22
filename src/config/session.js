import session from 'express-session';
import MySQLStoreFactory from 'express-mysql-session';
import { pool } from './db.js';
import { env } from './env.js';

const MySQLStore = MySQLStoreFactory(session);

const sessionStore = new MySQLStore({
  schema: {
    tableName: 'sessions',
    columnNames: {
      session_id: 'session_id',
      expires: 'expires',
      data: 'data',
    },
  },
}, pool);

export const sessionMiddleware = session({
  name: env.SESSION_NAME,
  secret: env.SESSION_SECRET,
  store: sessionStore,
  resave: false,
  saveUninitialized: false,
  cookie: {
    httpOnly: true,
    secure: env.NODE_ENV === 'production',
    sameSite: 'lax',
    maxAge: 1000 * 60 * 60 * 8,
  },
});

export default sessionMiddleware;
