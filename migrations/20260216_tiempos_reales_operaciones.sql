-- =============================================================================
-- SCRIPT DE MIGRACIÓN: REFINAMIENTO DE TIEMPOS Y COSTOS EN OPERACIONES
-- FECHA: 16-02-2026
-- OBJETIVO: Integrar el cálculo de horas reales en la vista de costos consolidada.
-- =============================================================================

START TRANSACTION;

-- 1. ACTUALIZAR VISTA DE COSTOS PARA INCLUIR TIEMPOS
-- Calculamos el total de horas por operación. Si no ha terminado, se usa NOW().
CREATE OR REPLACE VIEW v_servicio_costos_detallados AS
SELECT 
    s.id AS servicio_id,
    o.id AS operacion_id,
    o.descripcion AS operacion_nombre,
    o.is_master,
    o.fecha_inicio,
    o.fecha_fin,
    -- Cálculo de duración en horas (con decimales para precisión)
    COALESCE(
        TIMESTAMPDIFF(SECOND, o.fecha_inicio, COALESCE(o.fecha_fin, NOW())) / 3600.0, 
        0
    ) AS horas_duracion,
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
