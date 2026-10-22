-- NANAI Miel Organica - sp_expirar_reservas
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_expirar_reservas$$
CREATE PROCEDURE sp_expirar_reservas()
BEGIN
  DECLARE v_pedido_id BIGINT UNSIGNED;
  DECLARE v_reserva_id BIGINT UNSIGNED;
  DECLARE v_producto_id BIGINT UNSIGNED;
  DECLARE v_cantidad INT UNSIGNED;
  DECLARE done INT DEFAULT FALSE;
  DECLARE cur CURSOR FOR 
    SELECT DISTINCT r.pedido_id 
    FROM order_reservations r
    JOIN orders o ON o.id = r.pedido_id
    JOIN order_status s ON s.id = o.estado_id
    WHERE r.estado = 'VIGENTE' 
      AND r.reserva_expira_en < NOW()
      AND s.codigo IN ('PENDIENTE_PAGO','PAGO_POR_VERIFICAR')
    FOR UPDATE SKIP LOCKED;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

  OPEN cur;
  read_loop: LOOP
    FETCH cur INTO v_pedido_id;
    IF done THEN LEAVE read_loop; END IF;

    BEGIN
      DECLARE done2 INT DEFAULT FALSE;
      DECLARE cur2 CURSOR FOR SELECT id, producto_id, cantidad FROM order_reservations WHERE pedido_id = v_pedido_id AND estado = 'VIGENTE' FOR UPDATE;
      DECLARE CONTINUE HANDLER FOR NOT FOUND SET done2 = TRUE;

      OPEN cur2;
      read_loop2: LOOP
        FETCH cur2 INTO v_reserva_id, v_producto_id, v_cantidad;
        IF done2 THEN LEAVE read_loop2; END IF;
        UPDATE order_reservations SET estado = 'EXPIRADA' WHERE id = v_reserva_id;
        INSERT INTO inventory_movements (producto_id, tipo, cantidad, stock_fisico_antes, stock_fisico_despues, stock_reservado_antes, stock_reservado_despues, origen, pedido_id, motivo)
        SELECT v_producto_id, 'LIBERACION', 0, stock_fisico, stock_fisico, 0, 0, 'EXPIRACION_RESERVA', v_pedido_id, 'Reserva expirada'
        FROM products WHERE id = v_producto_id;
      END LOOP;
      CLOSE cur2;
    END;

    CALL sp_cambiar_estado_pedido(v_pedido_id, 'CANCELADO', NULL, 'Reserva expirada por TTL', NULL, NULL);
  END LOOP;
  CLOSE cur;

  SELECT 'OK' AS resultado;
END$$

DELIMITER ;
