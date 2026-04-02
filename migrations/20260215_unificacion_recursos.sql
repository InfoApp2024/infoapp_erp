-- =============================================================================
-- SCRIPT DE MIGRACIÓN: UNIFICACIÓN DE RECURSOS Y OPERACIONES
-- FECHA: 15-02-2026
-- OBJETIVO: Asegurar que todo recurso pertenezca a una operación (Master o Detallada)
-- =============================================================================

START TRANSACTION;

-- 1. ADICIÓN DE COLUMNA DE CONTROL EN OPERACIONES
-- Permite identificar la operación "Alistamiento/General" de cada servicio
ALTER TABLE operaciones ADD COLUMN IF NOT EXISTS is_master TINYINT(1) DEFAULT 0;

-- 2. CREACIÓN DE OPERACIÓN MAESTRA PARA SERVICIOS EXISTENTES
-- Solo se crea para servicios que no tengan ya una operación marcada como maestra
INSERT INTO operaciones (servicio_id, descripcion, fecha_inicio, is_master, observaciones)
SELECT 
    s.id, 
    'Alistamiento/General (Maestra)', 
    COALESCE(s.fecha_registro, NOW()), 
    1, 
    'Operación generada automáticamente por el sistema para unificar recursos'
FROM servicios s
WHERE NOT EXISTS (
    SELECT 1 FROM operaciones o 
    WHERE o.servicio_id = s.id AND o.is_master = 1
);

-- 3. MIGRACIÓN DE RECURSOS HUÉRFANOS (STAFF)
-- Relaciona el personal con la operación maestra de su servicio correspondiente
UPDATE servicio_staff ss
JOIN operaciones o ON ss.servicio_id = o.servicio_id AND o.is_master = 1
SET ss.operacion_id = o.id
WHERE ss.operacion_id IS NULL;

-- 4. MIGRACIÓN DE RECURSOS HUÉRFANOS (REPUESTOS)
-- Relaciona los repuestos con la operación maestra de su servicio correspondiente
UPDATE servicio_repuestos sr
JOIN operaciones o ON sr.servicio_id = o.servicio_id AND o.is_master = 1
SET sr.operacion_id = o.id
WHERE sr.operacion_id IS NULL;

-- 5. RESTRICCIÓN DE INTEGRIDAD (NOT NULL)
-- Una vez que todos los registros han sido linkeados, forzamos la integridad
ALTER TABLE servicio_staff MODIFY COLUMN operacion_id INT NOT NULL;
ALTER TABLE servicio_repuestos MODIFY COLUMN operacion_id INT NOT NULL;

-- 6. RESTRICCIONES DE UNICIDAD (Opcional pero Recomendado según propuesta)
-- Evita que el mismo técnico sea asignado dos veces al mismo servicio en distintas operaciones.
-- NOTA: Se intenta borrar primero si existe para garantizar la actualización de la estructura.
-- En MySQL, si se desea idempotencia estricta, se suele ignorar el error o usar un bloque PROCEDURE.
-- Aquí usaremos un nombre de índice versionado para evitar colisiones con ejecuciones fallidas previas.
ALTER TABLE servicio_staff ADD UNIQUE INDEX IF NOT EXISTS idx_staff_servicio_unificacion (servicio_id, staff_id);

-- 7. CREACIÓN DE VISTA DE CONSOLIDACIÓN (REPORTES)
CREATE OR REPLACE VIEW v_servicio_costos_detallados AS
SELECT 
    s.id AS servicio_id,
    o.id AS operacion_id,
    o.descripcion AS operacion_nombre,
    o.is_master,
    COALESCE(SUM(sr.cantidad * sr.costo_unitario), 0) AS subtotal_repuestos,
    COUNT(DISTINCT ss.staff_id) AS total_personal
FROM servicios s
JOIN operaciones o ON s.id = o.servicio_id
LEFT JOIN servicio_repuestos sr ON o.id = sr.operacion_id
LEFT JOIN servicio_staff ss ON o.id = ss.operacion_id
GROUP BY s.id, o.id;

COMMIT;

-- =============================================================================
-- FIN DEL SCRIPT
-- =============================================================================
