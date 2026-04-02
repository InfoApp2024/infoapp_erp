-- =============================================================================
-- SCRIPT DE TRIGGERS: INTEGRIDAD OPERATIVA (MOVE TO MASTER)
-- FECHA: 15-02-2026
-- OBJETIVO: Protege la Operación Maestra y mueve recursos automáticamente al borrar operaciones.
-- =============================================================================

DELIMITER //

DROP TRIGGER IF EXISTS tg_operaciones_before_delete //

CREATE TRIGGER tg_operaciones_before_delete
BEFORE DELETE ON operaciones
FOR EACH ROW
BEGIN
    DECLARE v_master_id INT;

    -- 1. Prohibir la eliminación de la operación maestra a nivel de motor de DB
    IF OLD.is_master = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar la Operación Maestra (Alistamiento/General).';
    END IF;

    -- 2. Identificar la operación maestra del mismo servicio
    SELECT id INTO v_master_id 
    FROM operaciones 
    WHERE servicio_id = OLD.servicio_id AND is_master = 1 
    LIMIT 1;

    -- 3. Mover recursos a la operación maestra antes de borrar la detallada
    -- Esto evita errores de FK ya que operacion_id es NOT NULL
    IF v_master_id IS NOT NULL THEN
        UPDATE servicio_staff SET operacion_id = v_master_id WHERE operacion_id = OLD.id;
        UPDATE servicio_repuestos SET operacion_id = v_master_id WHERE operacion_id = OLD.id;
    END IF;
END //

DELIMITER ;

-- =============================================================================
-- FIN DEL SCRIPT
-- =============================================================================
