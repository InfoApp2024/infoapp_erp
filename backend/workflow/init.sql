-- ============================================================================
-- MÓDULO: Workflow (Estados y Transiciones)
-- PROPÓSITO: Inicializar los estados base y el workflow estándar de servicios.
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Asegurar Estados Base del Sistema
INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES
('ABIERTO', 'Abierto', 'Servicio registrado, pendiente de programación', 0, 1, 1),
('PROGRAMADO', 'Programado', 'Servicio con fecha establecida', 0, 1, 2),
('ASIGNADO', 'Asignado', 'Servicio con técnico responsable', 0, 1, 3),
('EN_EJECUCION', 'En Ejecución', 'Trabajo en campo iniciado', 0, 1, 4),
('FINALIZADO', 'Finalizado', 'Trabajo terminado técnicamente', 1, 0, 5),
('CERRADO', 'Cerrado', 'Cierre administrativo definitivo', 1, 0, 6),
('CANCELADO', 'Cancelado', 'Servicio anulado', 1, 0, 7)
ON DUPLICATE KEY UPDATE 
    nombre=VALUES(nombre), 
    descripcion=VALUES(descripcion), 
    es_final=VALUES(es_final), 
    permite_edicion=VALUES(permite_edicion), 
    orden=VALUES(orden);

-- 2. Procedimiento de Inicialización de Workflow
DELIMITER //

CREATE PROCEDURE IF NOT EXISTS PopulateWorkflowData()
BEGIN
    DECLARE states_count INT;
    
    -- Verificar si ya existen estados configurados para el módulo servicio
    SELECT COUNT(*) INTO states_count FROM estados_proceso WHERE modulo = 'servicio';
    
    IF states_count <= 1 THEN -- 0 o solo LEGALIZADO
        
        -- Insertar Estados de Usuario Estándar
        INSERT IGNORE INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre) VALUES
        ('Abierto', '#2196F3', 'servicio', 'ABIERTO', 10, 0),
        ('Programado', '#FF9800', 'servicio', 'PROGRAMADO', 20, 0),
        ('Asignado', '#9C27B0', 'servicio', 'ASIGNADO', 30, 0),
        ('En Ejecución', '#673AB7', 'servicio', 'EN_EJECUCION', 40, 0),
        ('Finalizado', '#4CAF50', 'servicio', 'FINALIZADO', 50, 1),
        ('Cerrado', '#607D8B', 'servicio', 'CERRADO', 60, 0),
        ('Cancelado', '#F44336', 'servicio', 'CANCELADO', 70, 0);

        -- Crear Transiciones Básicas
        -- (Uso de INSERT IGNORE y lógica condicional para evitar duplicidad)
        
        -- Programar
        INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Programar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'ABIERTO' AND e2.estado_base_codigo = 'PROGRAMADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        -- Asignar
        INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Asignar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'PROGRAMADO' AND e2.estado_base_codigo = 'ASIGNADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        -- Iniciar
        INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Iniciar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'ASIGNADO' AND e2.estado_base_codigo = 'EN_EJECUCION'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        -- Finalizar (Automática por firma)
        INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Finalizar', 'servicio', 'FIRMA_CLIENTE'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'EN_EJECUCION' AND e2.estado_base_codigo = 'FINALIZADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        -- Cerrar
        INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Cerrar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'FINALIZADO' AND e2.estado_base_codigo = 'CERRADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

    END IF;
END //

DELIMITER ;

CALL PopulateWorkflowData();
DROP PROCEDURE IF EXISTS PopulateWorkflowData;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Workflow inicializado correctamente' as mensaje;
