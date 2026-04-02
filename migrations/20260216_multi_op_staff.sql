-- =============================================================================
-- SCRIPT DE MIGRACIÓN: SOPORTE MULTI-OPERACIÓN PARA PERSONAL
-- FECHA: 16-02-2026
-- OBJETIVO: Permitir que un técnico participe en múltiples operaciones del mismo servicio.
-- =============================================================================

START TRANSACTION;

-- 1. ELIMINAR ÍNDICE ÚNICO RESTRICTIVO
-- Este índice impedía que el mismo staff_id se repitiera en el mismo servicio_id.
ALTER TABLE servicio_staff DROP INDEX IF EXISTS idx_staff_servicio_unificacion;

-- 2. CREAR NUEVO ÍNDICE ÚNICO COMPUESTO
-- Ahora la unicidad se define por la combinación de Servicio, Staff y Operación.
ALTER TABLE servicio_staff ADD UNIQUE INDEX IF NOT EXISTS idx_staff_serv_op (servicio_id, staff_id, operacion_id);

-- 3. ACTUALIZAR VISTA DE COSTOS (DISTINCT)
-- Aseguramos que el conteo de personal total por servicio no duplique técnicos 
-- si estos participan en múltiples operaciones.
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
