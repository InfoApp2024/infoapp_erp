-- ============================================================================
-- SCRIPT: Migrar tabla estados_proceso para incluir estados base
-- PROPÓSITO: Agregar columnas para vincular estados personalizados con estados base
-- FECHA: 2026-02-02
-- ============================================================================

-- Paso 1: Agregar columnas nuevas a estados_proceso
ALTER TABLE estados_proceso 
ADD COLUMN estado_base_codigo VARCHAR(20) DEFAULT 'ABIERTO' 
  COMMENT 'Código del estado base del sistema' AFTER color;

ALTER TABLE estados_proceso 
ADD COLUMN bloquea_cierre BOOLEAN DEFAULT 0 
  COMMENT 'Indica si este estado bloquea el cierre del servicio' AFTER estado_base_codigo;

-- Paso 2: Crear índice para mejorar performance
CREATE INDEX idx_estado_base_codigo ON estados_proceso(estado_base_codigo);

-- Paso 3: Agregar foreign key
ALTER TABLE estados_proceso 
ADD CONSTRAINT fk_estado_base 
FOREIGN KEY (estado_base_codigo) 
REFERENCES estados_base(codigo) 
ON UPDATE CASCADE
ON DELETE RESTRICT;
