-- accounting_phase_14_snapshot_fix.sql
-- Propósito: Corregir el esquema de fac_control_servicios para soportar el desglose de MO/Repuestos
-- y permitir estados comerciales extendidos.

SET NAMES utf8mb4;

-- 1. Agregar las columnas de desglose si no existen
ALTER TABLE fac_control_servicios 
ADD COLUMN IF NOT EXISTS total_repuestos DECIMAL(18,2) DEFAULT 0.00 AFTER valor_snapshot,
ADD COLUMN IF NOT EXISTS total_mano_obra DECIMAL(18,2) DEFAULT 0.00 AFTER total_repuestos;

-- 2. Modificar la columna de estado para que no sea ENUM (evitar errores de restricción)
-- y dar soporte a 'PENDIENTE_CAUSACION', 'CAUSADO', etc.
ALTER TABLE fac_control_servicios 
MODIFY COLUMN estado_comercial_cache VARCHAR(50) DEFAULT 'NO_FACTURADO';

-- 3. Asegurar que los registros actuales tengan un valor coherente
UPDATE fac_control_servicios 
SET estado_comercial_cache = 'NO_FACTURADO' 
WHERE estado_comercial_cache IS NULL OR estado_comercial_cache = '';
