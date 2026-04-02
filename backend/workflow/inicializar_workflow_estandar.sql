-- ============================================================================
-- SCRIPT: Inicialización de Workflow Estándar (CORREGIDO)
-- PROPÓSITO: Crear los estados de usuario por defecto y sus transiciones
-- FECHA: 2026-02-06
-- CAMBIOS: Ajuste en nombre de tabla 'transiciones_estado' y creación de columnas faltantes
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- ----------------------------------------------------------------------------
-- 1. ACTUALIZA ESTRUCTURA DE TABLAS (Schema Migration)
-- ----------------------------------------------------------------------------

-- Asegurar índice único en estados_proceso para prevenir duplicados
SET @exist := (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'estados_proceso' AND index_name = 'idx_unique_nombre_modulo');
SET @sql := IF (@exist = 0, 'ALTER TABLE estados_proceso ADD UNIQUE INDEX idx_unique_nombre_modulo (nombre_estado, modulo)', 'SELECT "Indice unico ya existe"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Agregar columna 'nombre' si no existe en transiciones_estado
SET @exist := (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'transiciones_estado' AND column_name = 'nombre');
SET @sql := IF (@exist = 0, 'ALTER TABLE transiciones_estado ADD COLUMN nombre VARCHAR(100) NULL AFTER estado_destino_id', 'SELECT "Columna nombre ya existe"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Agregar columna 'trigger_code' para la automatización (Nueva funcionalidad)
SET @exist := (SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'transiciones_estado' AND column_name = 'trigger_code');
SET @sql := IF (@exist = 0, 'ALTER TABLE transiciones_estado ADD COLUMN trigger_code VARCHAR(50) NULL COMMENT "MANUAL, FIRMA_CLIENTE, FOTO_SUBIDA, ASIGNAR_PERSONAL" AFTER nombre', 'SELECT "Columna trigger_code ya existe"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- Garantizar unicidad de transiciones: no puede haber dos filas con mismo modulo+origen+destino
-- Esto previene botones de acción duplicados en la UI sin importar cuántas veces corra el setup
SET @exist := (SELECT COUNT(*) FROM information_schema.statistics WHERE table_schema = DATABASE() AND table_name = 'transiciones_estado' AND index_name = 'uq_transicion_modulo');
SET @sql := IF (@exist = 0, 'ALTER TABLE transiciones_estado ADD UNIQUE KEY uq_transicion_modulo (modulo, estado_origen_id, estado_destino_id)', 'SELECT "Indice unico transiciones ya existe"');
PREPARE stmt FROM @sql; EXECUTE stmt; DEALLOCATE PREPARE stmt;

-- ----------------------------------------------------------------------------
-- 2, 3 y 4. POBLACIÓN CONDICIONAL DE DATOS (Solo si no hay estados)
-- ----------------------------------------------------------------------------

DELIMITER //

CREATE PROCEDURE IF NOT EXISTS PopulateWorkflowData()
BEGIN
    DECLARE states_serv_count INT;
    DECLARE trans_serv_count INT;
    DECLARE states_equi_count INT;
    DECLARE trans_equi_count INT;
    DECLARE states_insp_count INT;
    DECLARE trans_insp_count INT;
    
    -- Verificar Módulo Servicio
    SELECT COUNT(*) INTO states_serv_count FROM estados_proceso WHERE modulo = 'servicio';
    SELECT COUNT(*) INTO trans_serv_count FROM transiciones_estado WHERE modulo = 'servicio';
    
    -- Verificar Módulo Equipos
    SELECT COUNT(*) INTO states_equi_count FROM estados_proceso WHERE modulo = 'equipo';
    SELECT COUNT(*) INTO trans_equi_count FROM transiciones_estado WHERE modulo = 'equipo';

    -- Verificar Módulo Inspecciones
    SELECT COUNT(*) INTO states_insp_count FROM estados_proceso WHERE modulo = 'inspecciones';
    SELECT COUNT(*) INTO trans_insp_count FROM transiciones_estado WHERE modulo = 'inspecciones';
    
    -- ------------------------------------------------------------------------
    -- A. MÓDULO: SERVICIO
    -- ------------------------------------------------------------------------
    IF states_serv_count = 0 AND trans_serv_count = 0 THEN
        
        -- 2. ASEGURAR ESTADOS BASE
        INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES
        ('ABIERTO', 'Abierto', 'Servicio registrado, pendiente de programación', 0, 1, 1),
        ('PROGRAMADO', 'Programado', 'Servicio con fecha establecida', 0, 1, 2),
        ('ASIGNADO', 'Asignado', 'Servicio con técnico responsable', 0, 1, 3),
        ('EN_EJECUCION', 'En Ejecución', 'Trabajo en campo iniciado', 0, 1, 4),
        ('FINALIZADO', 'Finalizado', 'Trabajo terminado técnicamente', 1, 0, 5),
        ('CERRADO', 'Cerrado', 'Cierre administrativo definitivo', 1, 0, 6),
        ('CANCELADO', 'Cancelado', 'Servicio anulado', 1, 0, 7)
        ON DUPLICATE KEY UPDATE nombre=VALUES(nombre);

        -- 3. INSERTAR ESTADOS DE USUARIO (Flujo Base Estándar)
        INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre) VALUES
        ('REGISTRADO', '#2196F3', 'servicio', 'ABIERTO', 1, 0),
        ('PROGRAMADO', '#FF9800', 'servicio', 'PROGRAMADO', 20, 0),
        ('ASIGNADO', '#9C27B0', 'servicio', 'ASIGNADO', 30, 0),
        ('EN PROCESO', '#009688', 'servicio', 'EN_EJECUCION', 40, 0),
        ('DISPONIBLE', '#00BCD4', 'servicio', 'FINALIZADO', 45, 0),
        ('SERVICIO LEGALIZADO', '#2E7D32', 'servicio', 'FINALIZADO', 55, 0),
        ('CERRADO', '#212121', 'servicio', 'CERRADO', 60, 0),
        ('ELIMINADO', '#F44336', 'servicio', 'CANCELADO', 99, 0)
        ON DUPLICATE KEY UPDATE color=VALUES(color), estado_base_codigo=VALUES(estado_base_codigo), orden=VALUES(orden);

        -- 4. CREAR TRANSICIONES
        -- Limpiamos transiciones antiguas para regenerar el flujo limpio (solo si estamos inicializando)
        DELETE FROM transiciones_estado WHERE modulo = 'servicio';

        -- 4.1 Flujo Operativo Principal
        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Programar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'ABIERTO' AND e2.estado_base_codigo = 'PROGRAMADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Asignar Personal', 'servicio', 'ASIGNAR_PERSONAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'PROGRAMADO' AND e2.estado_base_codigo = 'ASIGNADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Iniciar Servicio', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'ASIGNADO' AND e2.estado_base_codigo = 'EN_EJECUCION'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Finalizar Trabajo', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'EN_EJECUCION' AND e2.estado_base_codigo = 'FINALIZADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Legalizar / Firmar', 'servicio', 'FIRMA_CLIENTE'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'FINALIZADO' AND e2.estado_base_codigo = 'FINALIZADO'
        AND e1.id != e2.id -- Para el caso de tener dos estados con base FINALIZADO (Ej: Disponible -> Legalizado)
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Cierre Administrativo', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo = 'FINALIZADO' AND e2.estado_base_codigo = 'CERRADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

        -- 4.2 Flujo de Cancelación / Eliminación (Desde estados iniciales)
        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Anular / Eliminar', 'servicio', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.estado_base_codigo IN ('ABIERTO', 'PROGRAMADO', 'ASIGNADO') 
        AND e2.estado_base_codigo = 'CANCELADO'
        AND e1.modulo = 'servicio' AND e2.modulo = 'servicio'
        ON DUPLICATE KEY UPDATE nombre = VALUES(nombre);

    END IF;

    -- ------------------------------------------------------------------------
    -- B. MÓDULO: EQUIPOS
    -- ------------------------------------------------------------------------
    IF states_equi_count = 0 AND trans_equi_count = 0 THEN

        -- B.1 Estados básicos para Equipos
        INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre) VALUES
        ('Activo', '#2196F3', 'equipo', 'ABIERTO', 1, 0),
        ('Inactivo', '#E91E63', 'equipo', 'CANCELADO', 2, 0)
        ON DUPLICATE KEY UPDATE color=VALUES(color), estado_base_codigo=VALUES(estado_base_codigo);

        -- B.2 Transición básica (Bidireccional para flexibilidad)
        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Inactivar', 'equipo', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.nombre_estado = 'Activo' AND e2.nombre_estado = 'Inactivo'
        AND e1.modulo = 'equipo' AND e2.modulo = 'equipo';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Reactivar', 'equipo', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.nombre_estado = 'Inactivo' AND e2.nombre_estado = 'Activo'
        AND e1.modulo = 'equipo' AND e2.modulo = 'equipo';

    END IF;

    -- ------------------------------------------------------------------------
    -- C. MÓDULO: INSPECCIÓN
    -- ------------------------------------------------------------------------
    IF states_insp_count = 0 AND trans_insp_count = 0 THEN

        -- C.1 Estados para Inspección
        INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre) VALUES
        ('Registrada', '#2196F3', 'inspecciones', 'ABIERTO', 1, 0),
        ('Aprobada', '#4CAF50', 'inspecciones', 'PROGRAMADO', 2, 0),
        ('Cerrada', '#757575', 'inspecciones', 'CERRADO', 3, 0)
        ON DUPLICATE KEY UPDATE color=VALUES(color), estado_base_codigo=VALUES(estado_base_codigo);

        -- C.2 Transiciones
        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Aprobar', 'inspecciones', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.nombre_estado = 'Registrada' AND e2.nombre_estado = 'Aprobada'
        AND e1.modulo = 'inspecciones' AND e2.modulo = 'inspecciones';

        INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
        SELECT e1.id, e2.id, 'Cerrar', 'inspecciones', 'MANUAL'
        FROM estados_proceso e1, estados_proceso e2
        WHERE e1.nombre_estado = 'Aprobada' AND e2.nombre_estado = 'Cerrada'
        AND e1.modulo = 'inspecciones' AND e2.modulo = 'inspecciones';

    END IF;
END //

DELIMITER ;

CALL PopulateWorkflowData();
DROP PROCEDURE IF EXISTS PopulateWorkflowData;

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Schema verificado y workflow protegido' as mensaje;
