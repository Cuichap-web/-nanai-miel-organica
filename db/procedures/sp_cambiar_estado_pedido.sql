-- NANAI Miel Organica - sp_cambiar_estado_pedido
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_cambiar_estado_pedido$$
CREATE PROCEDURE sp_cambiar_estado_pedido(
  IN p_pedido_id BIGINT UNSIGNED,
  IN p_estado_destino_codigo VARCHAR(30),
  IN p_usuario_id BIGINT UNSIGNED,
  IN p_motivo VARCHAR(255),
  IN p_ip VARCHAR(45),
  IN p_user_agent VARCHAR(255)
)
BEGIN
  DECLARE v_estado_actual_id BIGINT UNSIGNED;
  DECLARE v_estado_destino_id BIGINT UNSIGNED;
  DECLARE v_consume_stock TINYINT(1) DEFAULT 0;
  DECLARE v_libera_stock TINYINT(1) DEFAULT 0;
  DECLARE v_exige_motivo TINYINT(1) DEFAULT 0;
  DECLARE v_requiere_usuario TINYINT(1) DEFAULT 0;
  DECLARE v_transition_exists INT DEFAULT 0;
  DECLARE v_reserva_id BIGINT UNSIGNED;
  DECLARE v_producto_id BIGINT UNSIGNED;
  DECLARE v_cantidad INT UNSIGNED;
  DECLARE v_stock_fisico INT UNSIGNED;
  DECLARE v_stock_reservado INT UNSIGNED;
  DECLARE done INT DEFAULT FALSE;
  DECLARE cur_reservas CURSOR FOR SELECT id, producto_id, cantidad FROM order_reservations WHERE pedido_id = p_pedido_id AND estado = 'VIGENTE';
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT estado_id INTO v_estado_actual_id FROM orders WHERE id = p_pedido_id FOR UPDATE;

  SELECT id, consume_stock, libera_stock, exige_motivo INTO v_estado_destino_id, v_consume_stock, v_libera_stock, v_exige_motivo
  FROM order_status WHERE codigo = p_estado_destino_codigo AND activo = 1 LIMIT 1;

  IF v_estado_destino_id IS NULL THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'ESTADO_NO_EXISTE';
  END IF;

  SELECT COUNT(*), COALESCE(MAX(requiere_usuario),0) INTO v_transition_exists, v_requiere_usuario
  FROM order_status_transition
  WHERE estado_origen_id = v_estado_actual_id AND estado_destino_id = v_estado_destino_id AND activo = 1;

  IF v_transition_exists = 0 THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'TRANSICION_NO_PERMITIDA';
  END IF;

  IF v_requiere_usuario = 1 AND (p_usuario_id IS NULL OR p_usuario_id = 0) THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'REQUIERE_USUARIO';
  END IF;

  IF v_exige_motivo = 1 AND (p_motivo IS NULL OR TRIM(p_motivo) = '') THEN
    SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'MOTIVO_OBLIGATORIO';
  END IF;

  IF v_consume_stock = 1 THEN
    OPEN cur_reservas;
    read_loop: LOOP
      FETCH cur_reservas INTO v_reserva_id, v_producto_id, v_cantidad;
      IF done THEN LEAVE read_loop; END IF;

      SELECT stock_fisico INTO v_stock_fisico FROM products WHERE id = v_producto_id FOR UPDATE;

      UPDATE products SET stock_fisico = stock_fisico - v_cantidad WHERE id = v_producto_id;

      INSERT INTO inventory_movements (producto_id, tipo, cantidad, stock_fisico_antes, stock_fisico_despues, stock_reservado_antes, stock_reservado_despues, origen, pedido_id, usuario_id, motivo)
      SELECT v_producto_id, 'VENTA', -v_cantidad, v_stock_fisico, v_stock_fisico - v_cantidad, 0, 0, 'VENTA_ONLINE', p_pedido_id, p_usuario_id, CONCAT('Consumo por ', p_estado_destino_codigo);

      UPDATE order_reservations SET estado = 'CONSUMIDA' WHERE id = v_reserva_id;
    END LOOP;
    CLOSE cur_reservas;
  END IF;

  IF v_libera_stock = 1 THEN
    OPEN cur_reservas;
    SET done = FALSE;
    read_loop2: LOOP
      FETCH cur_reservas INTO v_reserva_id, v_producto_id, v_cantidad;
      IF done THEN LEAVE read_loop2; END IF;
      UPDATE order_reservations SET estado = 'LIBERADA' WHERE id = v_reserva_id;
      INSERT INTO inventory_movements (producto_id, tipo, cantidad, stock_fisico_antes, stock_fisico_despues, stock_reservado_antes, stock_reservado_despues, origen, pedido_id, usuario_id, motivo)
      SELECT v_producto_id, 'LIBERACION', 0, stock_fisico, stock_fisico, 0, 0, 'LIBERACION_RESERVA', p_pedido_id, p_usuario_id, CONCAT('Liberacion por ', p_estado_destino_codigo)
      FROM products WHERE id = v_producto_id;
    END LOOP;
    CLOSE cur_reservas;
  END IF;

  UPDATE orders SET estado_id = v_estado_destino_id, updated_at = CURRENT_TIMESTAMP WHERE id = p_pedido_id;

  INSERT INTO order_status_history (pedido_id, estado_anterior_id, estado_nuevo_id, usuario_id, motivo, ip, user_agent)
  VALUES (p_pedido_id, v_estado_actual_id, v_estado_destino_id, p_usuario_id, p_motivo, p_ip, p_user_agent);

  COMMIT;
  SELECT 'OK' AS resultado;
END$$

DELIMITER ;
