-- fix_comercial_consistency_final.sql
-- Propósito: Sincronizar ENUM con el código PHP y migrar datos inconsistentes
-- Autor: Antigravity AI (Senior Architect)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Asegurar que el ENUM soporte todos los estados requeridos por el Negocio
-- Incluimos 'NO_FACTURADO' como el nombre estándar oficial
ALTER TABLE fac_control_servicios 
MODIFY COLUMN estado_comercial_cache ENUM('NO_FACTURADO', 'PENDIENTE', 'CAUSADO', 'FACTURACION_PARCIAL', 'FACTURADO_TOTAL', 'ANULADO') 
DEFAULT 'NO_FACTURADO';

-- 2. Migrar registros que quedaron atrapados con el nombre antiguo 'PENDIENTE'
UPDATE fac_control_servicios 
SET estado_comercial_cache = 'NO_FACTURADO' 
WHERE estado_comercial_cache = 'PENDIENTE';

-- 3. Limpieza: Si ya no hay dependencias de 'PENDIENTE', podríamos dejar el ENUM limpio
-- pero por seguridad lo mantenemos en esta fase de transición.

SET FOREIGN_KEY_CHECKS = 1;
