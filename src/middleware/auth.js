export function requireAuth(req, res, next) {
  if (!req.session || !req.session.userId) {
    return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'No autenticado' } });
  }
  next();
}

export function requireRole(...roles) {
  return (req, res, next) => {
    if (!req.session || !req.session.userRoles) {
      return res.status(401).json({ success: false, error: { code: 'UNAUTHORIZED', message: 'No autenticado' } });
    }
    const hasRole = req.session.userRoles.some((r) => roles.includes(r));
    if (!hasRole) {
      return res.status(403).json({ success: false, error: { code: 'FORBIDDEN', message: 'Sin permisos' } });
    }
    next();
  };
}

export function attachUser(req, res, next) {
  if (req.session && req.session.userId) {
    req.user = {
      id: req.session.userId,
      email: req.session.userEmail,
      nombre: req.session.userNombre,
      roles: req.session.userRoles || [],
    };
  }
  next();
}
