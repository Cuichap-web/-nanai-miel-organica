-- SP webhook pago
DELIMITER $$

DROP PROCEDURE IF EXISTS sp_aplicar_webhook_pago$$
CREATE PROCEDURE sp_aplicar_webhook_pago(
  IN p_provider_event_id VARCHAR(150),
  IN p_pedido_codigo VARCHAR(20),
  IN p_estado VARCHAR(20),
  IN p_referencia_externa VARCHAR(150),
  IN p_respuesta JSON
)
BEGIN
  DECLARE v_pago_id BIGINT UNSIGNED;
  DECLARE v_pedido_id BIGINT UNSIGNED;
  DECLARE v_estado_actual VARCHAR(20);
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;

  SELECT id INTO v_pago_id FROM payments WHERE provider_event_id = p_provider_event_id LIMIT 1 FOR UPDATE;
  IF v_pago_id IS NOT NULL THEN
    COMMIT;
    SELECT 'DUPLICADO' AS resultado;
  ELSE
    SELECT id INTO v_pedido_id FROM orders WHERE codigo = p_pedido_codigo FOR UPDATE;
    IF v_pedido_id IS NULL THEN
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'PEDIDO_NO_EXISTE';
    END IF;

    SELECT estado INTO v_estado_actual FROM payments WHERE pedido_id = v_pedido_id ORDER BY id DESC LIMIT 1 FOR UPDATE;

    INSERT INTO payments (pedido_id, proveedor, estado, monto, moneda, referencia_externa, provider_event_id, respuesta_proveedor)
    SELECT v_pedido_id, 'TARJETA', IF(p_estado='APROBADO','APROBADO','RECHAZADO'), total, 'PEN', p_referencia_externa, p_provider_event_id, p_respuesta
    FROM orders WHERE id = v_pedido_id;

    IF p_estado = 'APROBADO' THEN
      CALL sp_cambiar_estado_pedido(v_pedido_id, 'PAGADO', NULL, 'Pago aprobado por webhook', NULL, NULL);
    END IF;

    COMMIT;
    SELECT 'OK' AS resultado;
  END IF;
END$$

DELIMITER ;
