export class AppError extends Error {
  constructor(message, statusCode = 500, code = 'INTERNAL_ERROR', details = null) {
    super(message);
    this.name = 'AppError';
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
    this.isOperational = true;
    Error.captureStackTrace(this, this.constructor);
  }
}

export const badRequest = (message, code = 'BAD_REQUEST', details = null) =>
  new AppError(message, 400, code, details);

export const unauthorized = (message = 'No autorizado', code = 'UNAUTHORIZED') =>
  new AppError(message, 401, code);

export const forbidden = (message = 'Prohibido', code = 'FORBIDDEN') =>
  new AppError(message, 403, code);

export const notFound = (message = 'Recurso no encontrado', code = 'NOT_FOUND') =>
  new AppError(message, 404, code);

export const conflict = (message, code = 'CONFLICT', details = null) =>
  new AppError(message, 409, code, details);

export default AppError;
