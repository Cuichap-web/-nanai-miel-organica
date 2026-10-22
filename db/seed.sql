-- NANAI Miel Organica - Seed
SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

INSERT INTO order_status (codigo, nombre, descripcion, consume_stock, libera_stock, exige_motivo, notifica_cliente, notifica_vendedor, es_final, orden, activo) VALUES
('PENDIENTE_PAGO', 'Pendiente de pago', 'Pedido creado, reserva activa', 0, 0, 0, 1, 0, 0, 1, 1),
('PAGO_POR_VERIFICAR', 'Pago por verificar', 'Pago manual enviado, esperando verificacion', 0, 0, 0, 1, 1, 0, 2, 1),
('PAGADO', 'Pagado', 'Pago confirmado', 0, 0, 0, 1, 1, 0, 3, 1),
('PENDIENTE_APROBACION', 'Pendiente de aprobacion', 'Esperando aprobacion del vendedor', 0, 0, 0, 0, 1, 0, 4, 1),
('APROBADO', 'Aprobado', 'Venta aprobada, stock consumido', 1, 0, 0, 1, 0, 0, 5, 1),
('DESAPROBADO', 'Desaprobado', 'Pedido desaprobado, reserva liberada', 0, 1, 1, 1, 0, 1, 6, 1),
('EN_PREPARACION', 'En preparacion', 'Preparando pedido', 0, 0, 0, 1, 0, 0, 7, 1),
('ENVIADO', 'Enviado', 'Pedido enviado', 0, 0, 0, 1, 0, 0, 8, 1),
('EN_TRANSITO', 'En transito', 'En camino', 0, 0, 0, 0, 0, 0, 9, 1),
('RECIBIDO', 'Recibido', 'Cliente confirma recepcion', 0, 0, 0, 1, 0, 0, 10, 1),
('COMPLETADO', 'Completado', 'Pedido finalizado', 0, 0, 0, 0, 0, 1, 11, 1),
('CANCELADO', 'Cancelado', 'Pedido cancelado', 0, 1, 1, 1, 0, 1, 12, 1);

INSERT INTO roles (codigo, nombre, descripcion, activo) VALUES
('ADMIN', 'Administrador', 'Acceso total al panel', 1),
('VENDEDOR', 'Vendedor', 'Gestion de pedidos e inventario', 1);

INSERT INTO permissions (codigo, nombre, modulo) VALUES
('dashboard.view', 'Ver dashboard', 'dashboard'),
('products.view', 'Ver productos', 'products'),
('products.create', 'Crear productos', 'products'),
('products.edit', 'Editar productos', 'products'),
('products.delete', 'Eliminar productos', 'products'),
('categories.manage', 'Gestionar categorias', 'categories'),
('orders.view', 'Ver pedidos', 'orders'),
('orders.manage', 'Gestionar pedidos', 'orders'),
('inventory.view', 'Ver inventario', 'inventory'),
('inventory.manage', 'Gestionar inventario', 'inventory'),
('sales.pos', 'Ventas presenciales', 'sales'),
('reports.view', 'Ver reportes', 'reports'),
('users.manage', 'Gestionar usuarios', 'users'),
('settings.manage', 'Gestionar configuracion', 'settings');

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.codigo = 'ADMIN';

INSERT INTO role_permissions (role_id, permission_id)
SELECT r.id, p.id FROM roles r, permissions p WHERE r.codigo = 'VENDEDOR' AND p.codigo IN ('dashboard.view','products.view','categories.manage','orders.view','orders.manage','inventory.view','inventory.manage','sales.pos','reports.view');

INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 0, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='PENDIENTE_PAGO' AND o2.codigo IN ('PAGO_POR_VERIFICAR','PAGADO','CANCELADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 0, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='PAGO_POR_VERIFICAR' AND o2.codigo IN ('PAGADO','CANCELADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 1, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='PAGADO' AND o2.codigo IN ('PENDIENTE_APROBACION','CANCELADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 1, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='PENDIENTE_APROBACION' AND o2.codigo IN ('APROBADO','DESAPROBADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 1, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='APROBADO' AND o2.codigo IN ('EN_PREPARACION','CANCELADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 1, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='EN_PREPARACION' AND o2.codigo IN ('ENVIADO','CANCELADO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 1, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='ENVIADO' AND o2.codigo IN ('EN_TRANSITO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 0, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='EN_TRANSITO' AND o2.codigo IN ('RECIBIDO');
INSERT INTO order_status_transition (estado_origen_id, estado_destino_id, requiere_usuario, activo)
SELECT o1.id, o2.id, 0, 1 FROM order_status o1, order_status o2 WHERE o1.codigo='RECIBIDO' AND o2.codigo IN ('COMPLETADO');

INSERT INTO settings (clave, valor, descripcion, tipo, editable) VALUES
('reserva_ttl_minutos', '30', 'TTL de reserva en minutos', 'NUMBER', 1),
('igv_porcentaje', '18', 'IGV (incluido)', 'NUMBER', 0),
('envio_local_gratis_desde', '100.00', 'Envio gratis desde', 'NUMBER', 1),
('envio_costo_local', '0.00', 'Costo envio local', 'NUMBER', 1),
('stock_bajo_umbral', '5', 'Umbral alerta stock bajo', 'NUMBER', 1),
('pedido_prefijo', 'NAN', 'Prefijo codigo pedido', 'STRING', 0),
('app_nombre', 'NANAI Miel Organica', 'Nombre de la app', 'STRING', 1),
('email_remitente', 'no-reply@nanai.pe', 'Email remitente', 'STRING', 1);

SET FOREIGN_KEY_CHECKS = 1;
