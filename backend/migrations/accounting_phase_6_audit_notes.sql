

-- 1. Agregar columna notas a servicios_logs
ALTER TABLE servicios_logs 
ADD COLUMN notas TEXT NULL COMMENT 'Comentarios manuales o alertas legales' AFTER timestamp;

-- 2. Índice para búsquedas por notas (opcional)
CREATE INDEX idx_servicios_logs_notas ON servicios_logs(notas(100));
