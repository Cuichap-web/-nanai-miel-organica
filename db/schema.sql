-- NANAI Miel Organica - Schema
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS inventory_movements;
DROP TABLE IF EXISTS notifications;
DROP TABLE IF EXISTS settings;
DROP TABLE IF EXISTS sales_pos_items;
DROP TABLE IF EXISTS sales_pos;
DROP TABLE IF EXISTS shipments;
DROP TABLE IF EXISTS agencies;
DROP TABLE IF EXISTS payments;
DROP TABLE IF EXISTS order_status_history;
DROP TABLE IF EXISTS order_reservations;
DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS order_status_transition;
DROP TABLE IF EXISTS order_status;
DROP TABLE IF EXISTS product_usage;
DROP TABLE IF EXISTS product_benefits;
DROP TABLE IF EXISTS product_features;
DROP TABLE IF EXISTS product_images;
DROP TABLE IF EXISTS products;
DROP TABLE IF EXISTS categories;
DROP TABLE IF EXISTS password_reset_codes;
DROP TABLE IF EXISTS user_roles;
DROP TABLE IF EXISTS role_permissions;
DROP TABLE IF EXISTS permissions;
DROP TABLE IF EXISTS roles;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS sessions;

CREATE TABLE sessions (
  session_id VARCHAR(128) NOT NULL,
  expires INT UNSIGNED NOT NULL,
  data MEDIUMTEXT,
  PRIMARY KEY (session_id),
  KEY idx_sessions_expires (expires)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE users (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  nombre VARCHAR(150) NOT NULL,
  email VARCHAR(150) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  ultimo_login DATETIME DEFAULT NULL,
  force_password_change TINYINT(1) NOT NULL DEFAULT 0,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE roles (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  codigo VARCHAR(50) NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  descripcion VARCHAR(255) DEFAULT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_roles_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE permissions (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  codigo VARCHAR(80) NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  modulo VARCHAR(50) NOT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_permissions_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE role_permissions (
  role_id BIGINT UNSIGNED NOT NULL,
  permission_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (role_id, permission_id),
  KEY idx_rp_permission (permission_id),
  CONSTRAINT fk_rp_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT,
  CONSTRAINT fk_rp_permission FOREIGN KEY (permission_id) REFERENCES permissions (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE user_roles (
  user_id BIGINT UNSIGNED NOT NULL,
  role_id BIGINT UNSIGNED NOT NULL,
  PRIMARY KEY (user_id, role_id),
  KEY idx_ur_role (role_id),
  CONSTRAINT fk_ur_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT,
  CONSTRAINT fk_ur_role FOREIGN KEY (role_id) REFERENCES roles (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE password_reset_codes (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  code_hash VARCHAR(255) NOT NULL,
  expires_at DATETIME NOT NULL,
  used_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_prc_user (user_id),
  KEY idx_prc_expires (expires_at),
  CONSTRAINT fk_prc_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE categories (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  nombre VARCHAR(150) NOT NULL,
  slug VARCHAR(150) NOT NULL,
  descripcion TEXT,
  orden INT NOT NULL DEFAULT 0,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_categories_slug (slug)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE products (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  categoria_id BIGINT UNSIGNED NOT NULL,
  nombre VARCHAR(200) NOT NULL,
  slug VARCHAR(200) NOT NULL,
  descripcion_corta VARCHAR(255) DEFAULT NULL,
  descripcion_larga TEXT,
  precio DECIMAL(10,2) NOT NULL,
  peso_grs INT UNSIGNED DEFAULT NULL,
  stock_fisico INT UNSIGNED NOT NULL DEFAULT 0,
  minimo_stock INT UNSIGNED NOT NULL DEFAULT 5,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  destacado TINYINT(1) NOT NULL DEFAULT 0,
  mostrar_en_catalogo TINYINT(1) NOT NULL DEFAULT 1,
  meta_title VARCHAR(150) DEFAULT NULL,
  meta_description VARCHAR(160) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_products_slug (slug),
  KEY idx_products_cat_act (categoria_id, activo),
  CONSTRAINT fk_products_categoria FOREIGN KEY (categoria_id) REFERENCES categories (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE product_images (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  ruta VARCHAR(255) NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  es_portada TINYINT(1) NOT NULL DEFAULT 0,
  alt_text VARCHAR(150) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_pi_prod (producto_id, orden),
  CONSTRAINT fk_pi_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE product_features (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  texto VARCHAR(150) NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_pf_producto (producto_id),
  CONSTRAINT fk_pf_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE product_benefits (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  texto VARCHAR(150) NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  advertencia_salud TINYINT(1) NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_pb_producto (producto_id),
  CONSTRAINT fk_pb_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE product_usage (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  texto TEXT NOT NULL,
  orden INT NOT NULL DEFAULT 0,
  PRIMARY KEY (id),
  KEY idx_pu_producto (producto_id),
  CONSTRAINT fk_pu_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_status (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  codigo VARCHAR(30) NOT NULL,
  nombre VARCHAR(50) NOT NULL,
  descripcion VARCHAR(255) DEFAULT NULL,
  consume_stock TINYINT(1) NOT NULL DEFAULT 0,
  libera_stock TINYINT(1) NOT NULL DEFAULT 0,
  exige_motivo TINYINT(1) NOT NULL DEFAULT 0,
  notifica_cliente TINYINT(1) NOT NULL DEFAULT 0,
  notifica_vendedor TINYINT(1) NOT NULL DEFAULT 0,
  es_final TINYINT(1) NOT NULL DEFAULT 0,
  orden INT NOT NULL DEFAULT 0,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_order_status_codigo (codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_status_transition (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  estado_origen_id BIGINT UNSIGNED NOT NULL,
  estado_destino_id BIGINT UNSIGNED NOT NULL,
  requiere_usuario TINYINT(1) NOT NULL DEFAULT 0,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  PRIMARY KEY (id),
  UNIQUE KEY uq_ost_transition (estado_origen_id, estado_destino_id),
  KEY idx_ost_destino (estado_destino_id),
  CONSTRAINT fk_ost_origen FOREIGN KEY (estado_origen_id) REFERENCES order_status (id) ON DELETE RESTRICT,
  CONSTRAINT fk_ost_destino FOREIGN KEY (estado_destino_id) REFERENCES order_status (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE orders (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  tipo_venta ENUM('ONLINE','PRESENCIAL') NOT NULL DEFAULT 'ONLINE',
  estado_id BIGINT UNSIGNED NOT NULL,
  cliente_nombre VARCHAR(150) NOT NULL,
  cliente_email VARCHAR(150) DEFAULT NULL,
  cliente_telefono VARCHAR(20) NOT NULL,
  cliente_dni VARCHAR(8) DEFAULT NULL,
  cliente_direccion VARCHAR(255) DEFAULT NULL,
  cliente_zona_distrito VARCHAR(100) DEFAULT NULL,
  modalidad_entrega ENUM('ENTREGA_LOCAL','ENVIO_AGENCIA') NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  costo_envio DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  total DECIMAL(10,2) NOT NULL,
  igv_incluido TINYINT(1) NOT NULL DEFAULT 1,
  reserva_expira_en DATETIME DEFAULT NULL,
  idempotency_key VARCHAR(64) DEFAULT NULL,
  usuario_id BIGINT UNSIGNED DEFAULT NULL,
  notas TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_orders_codigo (codigo),
  UNIQUE KEY uq_orders_idempotency (idempotency_key),
  KEY idx_orders_codigo_idx (codigo),
  KEY idx_orders_estado_created (estado_id, created_at),
  KEY idx_orders_tipo_fecha (tipo_venta, created_at),
  KEY idx_orders_reserva (reserva_expira_en),
  CONSTRAINT fk_orders_estado FOREIGN KEY (estado_id) REFERENCES order_status (id) ON DELETE RESTRICT,
  CONSTRAINT fk_orders_usuario FOREIGN KEY (usuario_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_items (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  pedido_id BIGINT UNSIGNED NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  nombre_producto VARCHAR(200) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  cantidad INT UNSIGNED NOT NULL,
  subtotal_linea DECIMAL(10,2) NOT NULL,
  descuento_unitario DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  descuento_total DECIMAL(10,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  KEY idx_oi_pedido (pedido_id),
  KEY idx_oi_producto (producto_id),
  CONSTRAINT fk_oi_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_oi_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_status_history (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  pedido_id BIGINT UNSIGNED NOT NULL,
  estado_anterior_id BIGINT UNSIGNED DEFAULT NULL,
  estado_nuevo_id BIGINT UNSIGNED NOT NULL,
  usuario_id BIGINT UNSIGNED DEFAULT NULL,
  motivo VARCHAR(255) DEFAULT NULL,
  ip VARCHAR(45) DEFAULT NULL,
  user_agent VARCHAR(255) DEFAULT NULL,
  fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_osh_pedido_fecha (pedido_id, fecha_cambio),
  CONSTRAINT fk_osh_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_osh_anterior FOREIGN KEY (estado_anterior_id) REFERENCES order_status (id) ON DELETE RESTRICT,
  CONSTRAINT fk_osh_nuevo FOREIGN KEY (estado_nuevo_id) REFERENCES order_status (id) ON DELETE RESTRICT,
  CONSTRAINT fk_osh_usuario FOREIGN KEY (usuario_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE order_reservations (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  pedido_id BIGINT UNSIGNED NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  cantidad INT UNSIGNED NOT NULL,
  reserva_expira_en DATETIME NOT NULL,
  estado ENUM('VIGENTE','CONSUMIDA','LIBERADA','EXPIRADA') NOT NULL DEFAULT 'VIGENTE',
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_or_reserva_estado_expira (estado, reserva_expira_en),
  KEY idx_or_reserva_producto (producto_id, estado),
  KEY idx_or_pedido (pedido_id),
  CONSTRAINT fk_or_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_or_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE payments (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  pedido_id BIGINT UNSIGNED NOT NULL,
  proveedor ENUM('TARJETA','YAPE','PLIN','TRANSFERENCIA','EFECTIVO') NOT NULL,
  estado ENUM('PENDIENTE','PENDIENTE_VERIFICACION','APROBADO','RECHAZADO','REEMBOLSADO','ANULADO') NOT NULL DEFAULT 'PENDIENTE',
  monto DECIMAL(10,2) NOT NULL,
  moneda CHAR(3) NOT NULL DEFAULT 'PEN',
  referencia_externa VARCHAR(150) DEFAULT NULL,
  provider_event_id VARCHAR(150) DEFAULT NULL,
  referencia_interna VARCHAR(50) DEFAULT NULL,
  evidencia_url VARCHAR(255) DEFAULT NULL,
  verificado_por BIGINT UNSIGNED DEFAULT NULL,
  fecha_verificacion DATETIME DEFAULT NULL,
  respuesta_proveedor JSON DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payments_provider_event (provider_event_id),
  KEY idx_pay_pedido (pedido_id),
  CONSTRAINT fk_pay_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_pay_verificado_por FOREIGN KEY (verificado_por) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE agencies (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  nombre VARCHAR(100) NOT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1,
  url_seguimiento_base VARCHAR(255) DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE shipments (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  pedido_id BIGINT UNSIGNED NOT NULL,
  agencia_id BIGINT UNSIGNED DEFAULT NULL,
  codigo_seguimiento VARCHAR(100) DEFAULT NULL,
  fecha_envio DATETIME DEFAULT NULL,
  fecha_entrega_estimado DATETIME DEFAULT NULL,
  url_seguimiento VARCHAR(255) DEFAULT NULL,
  notas TEXT,
  usuario_id BIGINT UNSIGNED DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_shipments_pedido (pedido_id),
  CONSTRAINT fk_shipments_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_shipments_agencia FOREIGN KEY (agencia_id) REFERENCES agencies (id) ON DELETE RESTRICT,
  CONSTRAINT fk_shipments_usuario FOREIGN KEY (usuario_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sales_pos (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  codigo VARCHAR(20) NOT NULL,
  usuario_id BIGINT UNSIGNED NOT NULL,
  cliente_nombre VARCHAR(150) DEFAULT NULL,
  medio_pago ENUM('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFERENCIA') NOT NULL,
  subtotal DECIMAL(10,2) NOT NULL,
  total DECIMAL(10,2) NOT NULL,
  igv_incluido TINYINT(1) NOT NULL DEFAULT 1,
  notas TEXT,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  UNIQUE KEY uq_sales_pos_codigo (codigo),
  KEY idx_sales_pos_fecha (created_at),
  CONSTRAINT fk_sales_pos_usuario FOREIGN KEY (usuario_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE sales_pos_items (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  venta_id BIGINT UNSIGNED NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  nombre_producto VARCHAR(200) NOT NULL,
  precio_unitario DECIMAL(10,2) NOT NULL,
  cantidad INT UNSIGNED NOT NULL,
  subtotal_linea DECIMAL(10,2) NOT NULL,
  PRIMARY KEY (id),
  CONSTRAINT fk_spi_venta FOREIGN KEY (venta_id) REFERENCES sales_pos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_spi_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE inventory_movements (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  producto_id BIGINT UNSIGNED NOT NULL,
  tipo ENUM('INGRESO','VENTA','AJUSTE','MERMA','LIBERACION','RESERVA') NOT NULL,
  cantidad INT NOT NULL,
  stock_fisico_antes INT UNSIGNED NOT NULL,
  stock_fisico_despues INT UNSIGNED NOT NULL,
  stock_reservado_antes INT UNSIGNED NOT NULL DEFAULT 0,
  stock_reservado_despues INT UNSIGNED NOT NULL DEFAULT 0,
  origen ENUM('VENTA_ONLINE','VENTA_PRESENCIAL','INGRESO_ALMACEN','AJUSTE_MANUAL','LIBERACION_RESERVA','EXPIRACION_RESERVA','MERMA') NOT NULL,
  pedido_id BIGINT UNSIGNED DEFAULT NULL,
  venta_presencial_id BIGINT UNSIGNED DEFAULT NULL,
  usuario_id BIGINT UNSIGNED DEFAULT NULL,
  motivo VARCHAR(255) DEFAULT NULL,
  fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_im_producto_fecha (producto_id, fecha),
  KEY idx_im_origen (origen),
  CONSTRAINT fk_im_producto FOREIGN KEY (producto_id) REFERENCES products (id) ON DELETE RESTRICT,
  CONSTRAINT fk_im_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT,
  CONSTRAINT fk_im_vp FOREIGN KEY (venta_presencial_id) REFERENCES sales_pos (id) ON DELETE RESTRICT,
  CONSTRAINT fk_im_usuario FOREIGN KEY (usuario_id) REFERENCES users (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE notifications (
  id BIGINT UNSIGNED AUTO_INCREMENT NOT NULL,
  tipo ENUM('PEDIDO_REGISTRADO','PAGO_CONFIRMADO','PEDIDO_APROBADO','PEDIDO_DESAPROBADO','PEDIDO_EN_PREPARACION','PEDIDO_ENVIADO','PEDIDO_RECIBIDO','RECUPERACION_CONTRASEÑA','PEDIDO_NUEVO_VENDEDOR','PAGO_POR_VERIFICAR') NOT NULL,
  destinatario_tipo ENUM('CLIENTE','VENDEDOR') NOT NULL,
  destinatario_email VARCHAR(150) NOT NULL,
  pedido_id BIGINT UNSIGNED DEFAULT NULL,
  asunto VARCHAR(200) NOT NULL,
  plantilla VARCHAR(100) NOT NULL,
  estado ENUM('PENDIENTE','ENVIADO','FALLIDO') NOT NULL DEFAULT 'PENDIENTE',
  intentos INT UNSIGNED NOT NULL DEFAULT 0,
  error_detalle TEXT,
  enviado_at DATETIME DEFAULT NULL,
  created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (id),
  KEY idx_not_estado_created (estado, created_at),
  CONSTRAINT fk_not_pedido FOREIGN KEY (pedido_id) REFERENCES orders (id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE settings (
  clave VARCHAR(100) NOT NULL,
  valor TEXT NOT NULL,
  descripcion VARCHAR(255) DEFAULT NULL,
  tipo ENUM('STRING','NUMBER','BOOLEAN','JSON') NOT NULL DEFAULT 'STRING',
  editable TINYINT(1) NOT NULL DEFAULT 1,
  updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (clave)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
