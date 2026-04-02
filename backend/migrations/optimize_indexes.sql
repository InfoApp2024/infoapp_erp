-- ============================================================================
-- SQL DE OPTIMIZACIÓN: ÍNDICES PARA LISTA DE SERVICIOS
-- ============================================================================
-- Propósito: Acelerar las subconsultas correlacionadas en listar_servicios.php
-- Fecha: 2026-02-08
-- ============================================================================

-- 1. Índice para conteo rápido de NOTAS (YA EXISTE, COMENTADO)
-- Acelera: (SELECT COUNT(*) FROM notas n WHERE n.id_servicio = s.id)
-- ALTER TABLE notas ADD INDEX idx_notas_servicio (id_servicio);

-- 2. Índice para verificación de FIRMAS
-- Acelera: (SELECT COUNT(*) FROM firmas fi WHERE fi.id_servicio = s.id)
ALTER TABLE firmas ADD INDEX idx_firmas_servicio (id_servicio);

-- 3. Índice para conteo de DESBLOQUEOS
-- Acelera: (SELECT COUNT(*) FROM servicios_desbloqueos_repuestos dr WHERE dr.servicio_id = s.id AND dr.usado = 0)
ALTER TABLE servicios_desbloqueos_repuestos ADD INDEX idx_desbloqueos_servicio_usado (servicio_id, usado);

-- ============================================================================
-- VERIFICACIÓN (Opcional)
-- Ejecutar SHOW INDEX FROM [tabla] para confirmar creación
-- ============================================================================
-- SHOW INDEX FROM notas;
-- SHOW INDEX FROM firmas;
-- SHOW INDEX FROM servicios_desbloqueos_repuestos;
