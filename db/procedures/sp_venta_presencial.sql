-- NANAI Miel Organica - sp_venta_presencial
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_venta_presencial$$
CREATE PROCEDURE sp_venta_presencial(
  IN p_usuario_id BIGINT UNSIGNED,
  IN p_cliente_nombre VARCHAR(150),
  IN p_medio_pago ENUM('EFECTIVO','TARJETA','YAPE','PLIN','TRANSFERENCIA'),
  IN p_items JSON,
  IN p_notas TEXT
)
BEGIN
  DECLARE v_venta_id BIGINT UNSIGNED;
  DECLARE v_codigo VARCHAR(20);
  DECLARE v_subtotal DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_total DECIMAL(10,2) DEFAULT 0.00;
  DECLARE v_idx INT DEFAULT 0;
  DECLARE v_cnt INT DEFAULT 0;
  DECLARE v_producto_id BIGINT UNSIGNED;
  DECLARE v_cantidad INT UNSIGNED;
  DECLARE v_precio DECIMAL(10,2);
  DECLARE v_nombre VARCHAR(200);
  DECLARE v_stock_fisico INT UNSIGNED;
  DECLARE v_correlativo INT UNSIGNED;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT COALESCE(MAX(id), 0) + 1 INTO v_correlativo FROM sales_pos;
  SET v_codigo = CONCAT('NAN-POS-', LPAD(v_correlativo, 6, '0'));

  SET v_cnt = JSON_LENGTH(p_items);
  WHILE v_idx < v_cnt DO
    SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].producto_id')));
    SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].cantidad')));
    SET v_precio = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].precio_unitario')));
    SET v_subtotal = v_subtotal + (v_precio * v_cantidad);
    SET v_idx = v_idx + 1;
  END WHILE;
  SET v_total = v_subtotal;

  INSERT INTO sales_pos (codigo, usuario_id, cliente_nombre, medio_pago, subtotal, total, igv_incluido, notas)
  VALUES (v_codigo, p_usuario_id, p_cliente_nombre, p_medio_pago, v_subtotal, v_total, 1, p_notas);
  SET v_venta_id = LAST_INSERT_ID();

  SET v_idx = 0;
  WHILE v_idx < v_cnt DO
    SET v_producto_id = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].producto_id')));
    SET v_cantidad = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].cantidad')));
    SET v_precio = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].precio_unitario')));
    SET v_nombre = JSON_UNQUOTE(JSON_EXTRACT(p_items, CONCAT('$[', v_idx, '].nombre_producto')));

    SELECT stock_fisico INTO v_stock_fisico FROM products WHERE id = v_producto_id FOR UPDATE;
    IF v_stock_fisico < v_cantidad THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'STOCK_INSUFICIENTE';
    END IF;

    INSERT INTO sales_pos_items (venta_id, producto_id, nombre_producto, precio_unitario, cantidad, subtotal_linea)
    VALUES (v_venta_id, v_producto_id, v_nombre, v_precio, v_cantidad, v_precio * v_cantidad);

    UPDATE products SET stock_fisico = stock_fisico - v_cantidad WHERE id = v_producto_id;

    INSERT INTO inventory_movements (producto_id, tipo, cantidad, stock_fisico_antes, stock_fisico_despues, stock_reservado_antes, stock_reservado_despues, origen, venta_presencial_id, usuario_id, motivo)
    VALUES (v_producto_id, 'VENTA', -v_cantidad, v_stock_fisico, v_stock_fisico - v_cantidad, 0, 0, 'VENTA_PRESENCIAL', v_venta_id, p_usuario_id, 'Venta presencial');

    SET v_idx = v_idx + 1;
  END WHILE;

  COMMIT;
  SELECT v_venta_id AS venta_id, v_codigo AS codigo, v_total AS total;
END$$

DELIMITER ;
