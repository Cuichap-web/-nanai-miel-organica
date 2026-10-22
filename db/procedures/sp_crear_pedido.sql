-- NANAI Miel Organica - Stored Procedures
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_crear_pedido$$
CREATE PROCEDURE sp_crear_pedido(
  IN p_codigo VARCHAR(20),
  IN p_tipo_venta ENUM('ONLINE','PRESENCIAL'),
  IN p_cliente_nombre VARCHAR(150),
  IN p_cliente_email VARCHAR(150),
  IN p_cliente_telefono VARCHAR(20),
  IN p_cliente_dni VARCHAR(8),
  IN p_cliente_direccion VARCHAR(255),
  IN p_cliente_zona_distrito VARCHAR(100),
  IN p_modalidad_entrega ENUM('ENTREGA_LOCAL','ENVIO_AGENCIA'),
  IN p_subtotal DECIMAL(10,2),
  IN p_costo_envio DECIMAL(10,2),
  IN p_total DECIMAL(10,2),
  IN p_idempotency_key VARCHAR(64),
  IN p_usuario_id BIGINT UNSIGNED,
  IN p_items JSON,
  IN p_reserva_ttl_minutos INT
)
BEGIN
  DECLARE v_pedido_id BIGINT UNSIGNED;
  DECLARE v_estado_id BIGINT UNSIGNED;
  DECLARE v_reserva_expira DATETIME;
  DECLARE v_idx INT DEFAULT 0;
  DECLARE v_cnt INT DEFAULT 0;
  DECLARE v_producto_id BIGINT UNSIGNED;
  DECLARE v_cantidad INT UNSIGNED;
  DECLARE v_precio DECIMAL(10,2);
  DECLARE v_nombre VARCHAR(200);
  DECLARE v_stock_fisico INT UNSIGNED;
  DECLARE v_reservas_vigentes INT UNSIGNED;
  DECLARE v_disponible INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT id INTO v_estado_id FROM order_status WHERE codigo = 'PENDIENTE_PAGO' AND activo = 1 LIMIT 1;
  SET v_reserva_expira = DATE_ADD(NOW(), INTERVAL p_reserva_ttl_minutos MINUTE);

  INSERT INTO orders (
    codigo, tipo_venta, estado_id, cliente_nombre, cliente_email, cliente_telefono,
    cliente_dni, cliente_direccion, cliente_zona_distrito, modalidad_entrega,
    subtotal, costo_envio, total, igv_incluido, reserva_expira_en, idempotency_key, usuario_id
  ) VALUES (
    p_codigo, p_tipo_venta, v_estado_id, p_cliente_nombre, p_cliente_email, p_cliente_telefono,
    p_cliente_dni, p_cliente_direccion, p_cliente_zona_distrito, p_modalidad_entrega,
    p_subtotal, p_costo_envio, p_total, 1, v_reserva_expira, p_idempotency_key, p_usuario_id
  );
  SET v_pedido_id = LAST_INSERT_ID();

  SET v_cnt = JSON_LENGTH(p_items);
  WHILE v_idx < v_cnt DO
    SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].producto_id')));
    SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].cantidad')));
    SET v_precio = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].precio_unitario')));
    SET v_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].nombre_producto')));

    SELECT stock_fisico INTO v_stock_fisico FROM products WHERE id = v_producto_id FOR UPDATE;

    SELECT COALESCE(SUM(cantidad), 0) INTO v_reservas_vigentes
    FROM order_reservations
    WHERE producto_id = v_producto_id AND estado = 'VIGENTE';

    SET v_disponible = v_stock_fisico - v_reservas_vigentes;
    IF v_disponible < v_cantidad THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOCK_INSUFICIENTE';
    END IF;

    INSERT INTO order_items (pedido_id, producto_id, nombre_producto, precio_unitario, cantidad, subtotal_linea, descuento_unitario, descuento_total)
    VALUES (v_pedido_id, v_producto_id, v_nombre, v_precio, v_cantidad, v_precio * v_cantidad, 0.00, 0.00);

    INSERT INTO order_reservations (pedido_id, producto_id, cantidad, reserva_expira_en, estado)
    VALUES (v_pedido_id, v_producto_id, v_cantidad, v_reserva_expira, 'VIGENTE');

    SET v_idx = v_idx + 1;
  END WHILE;

  INSERT INTO order_status_history (pedido_id, estado_anterior_id, estado_nuevo_id, usuario_id, motivo)
  VALUES (v_pedido_id, NULL, v_estado_id, NULL, 'Pedido creado');

  COMMIT;
  SELECT v_pedido_id AS pedido_id, p_codigo AS codigo;
END$$

DELIMITER ;
