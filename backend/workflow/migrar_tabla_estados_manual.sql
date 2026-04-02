-- ============================================================================
-- SCRIPT ALTERNATIVO: Si el script principal falla, ejecuta estos comandos UNO POR UNO
-- ============================================================================

-- Comando 1: Agregar columna estado_base_codigo
ALTER TABLE estados_proceso 
ADD COLUMN estado_base_codigo VARCHAR(20) DEFAULT 'ABIERTO' AFTER color;

-- Comando 2: Agregar columna bloquea_cierre
ALTER TABLE estados_proceso 
ADD COLUMN bloquea_cierre BOOLEAN DEFAULT 0 AFTER estado_base_codigo;

-- Comando 3: Crear índice
CREATE INDEX idx_estado_base_codigo ON estados_proceso(estado_base_codigo);

-- Comando 4: Agregar foreign key
ALTER TABLE estados_proceso 
ADD CONSTRAINT fk_estado_base 
FOREIGN KEY (estado_base_codigo) 
REFERENCES estados_base(codigo) 
ON UPDATE CASCADE
ON DELETE RESTRICT;

-- Comando 5: Verificar estructura (ejecutar por separado)
-- DESCRIBE estados_proceso;

-- Comando 6: Ver datos (ejecutar por separado)
-- SELECT id, nombre_estado, estado_base_codigo, bloquea_cierre FROM estados_proceso LIMIT 5;
