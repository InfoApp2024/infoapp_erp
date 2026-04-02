-- ============================================================================
-- SCRIPT: Add Trigger Completion Flags
-- PROPÓSITO: Agregar columnas para rastrear confirmación de triggers
-- FECHA: 2026-02-11
-- ============================================================================

SET NAMES utf8mb4;

-- Agregar columna 'fotos_confirmadas' si no existe
SET @exist := (SELECT COUNT(*) FROM information_schema.columns 
               WHERE table_schema = DATABASE() 
               AND table_name = 'servicios' 
               AND column_name = 'fotos_confirmadas');
SET @sql := IF (@exist = 0, 
    'ALTER TABLE servicios ADD COLUMN fotos_confirmadas TINYINT(1) DEFAULT 0 COMMENT ''Usuario confirmó que terminó de subir fotos'' AFTER suministraron_repuestos', 
    'SELECT "Columna fotos_confirmadas ya existe"');
PREPARE stmt FROM @sql; 
EXECUTE stmt; 
DEALLOCATE PREPARE stmt;

-- Agregar columna 'firma_confirmada' si no existe
SET @exist := (SELECT COUNT(*) FROM information_schema.columns 
               WHERE table_schema = DATABASE() 
               AND table_name = 'servicios' 
               AND column_name = 'firma_confirmada');
SET @sql := IF (@exist = 0, 
    'ALTER TABLE servicios ADD COLUMN firma_confirmada TINYINT(1) DEFAULT 0 COMMENT ''Usuario confirmó que obtuvo firma del cliente'' AFTER fotos_confirmadas', 
    'SELECT "Columna firma_confirmada ya existe"');
PREPARE stmt FROM @sql; 
EXECUTE stmt; 
DEALLOCATE PREPARE stmt;

SELECT 'Columnas de confirmación de triggers agregadas exitosamente' as mensaje;
