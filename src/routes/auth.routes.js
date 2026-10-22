import { Router } from 'express';
import { verify } from '@node-rs/argon2';
import { pool } from '../config/db.js';
import { requireAuth } from '../middleware/auth.js';

const router = Router();

router.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({ success: false, error: { code: 'VALIDATION_ERROR', message: 'Email y contraseña requeridos' } });
    }

    const [users] = await pool.query('SELECT id, nombre, email, password_hash, activo FROM users WHERE email = ? LIMIT 1', [email]);
    if (users.length === 0) {
      return res.status(401).json({ success: false, error: { code: 'INVALID_CREDENTIALS', message: 'Credenciales inválidas' } });
    }

    const user = users[0];
    if (!user.activo) {
      return res.status(403).json({ success: false, error: { code: 'USER_INACTIVE', message: 'Usuario inactivo' } });
    }

    const valid = await verify(user.password_hash, password);
    if (!valid) {
      return res.status(401).json({ success: false, error: { code: 'INVALID_CREDENTIALS', message: 'Credenciales inválidas' } });
    }

    const [roles] = await pool.query(
      `SELECT r.codigo FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? AND r.activo = 1`,
      [user.id]
    );

    await pool.query('UPDATE users SET ultimo_login = NOW() WHERE id = ?', [user.id]);

    req.session.userId = user.id;
    req.session.userEmail = user.email;
    req.session.userNombre = user.nombre;
    req.session.userRoles = roles.map((r) => r.codigo);

    res.json({ success: true, data: { user: { id: user.id, nombre: user.nombre, email: user.email, roles: req.session.userRoles } } });
  } catch (error) {
    next(error);
  }
});

router.post('/logout', requireAuth, (req, res) => {
  req.session.destroy((err) => {
    if (err) return res.status(500).json({ success: false, error: { code: 'LOGOUT_ERROR', message: 'Error al cerrar sesión' } });
    res.clearCookie(req.session.cookie.name || 'nanai.sid');
    res.json({ success: true, message: 'Sesión cerrada' });
  });
});

router.get('/me', requireAuth, (req, res) => {
  res.json({ success: true, data: { user: { id: req.session.userId, email: req.session.userEmail, nombre: req.session.userNombre, roles: req.session.userRoles } } });
});

export default router;
