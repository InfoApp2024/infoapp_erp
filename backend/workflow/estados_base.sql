-- ============================================================================
-- SCRIPT: Crear tabla de estados base del sistema
-- PROPÓSITO: Definir estados semánticos para analytics y validación de negocio
-- FECHA: 2026-02-02
-- ============================================================================

-- Crear tabla de estados base
CREATE TABLE IF NOT EXISTS estados_base (
  id INT AUTO_INCREMENT PRIMARY KEY,
  codigo VARCHAR(20) UNIQUE NOT NULL COMMENT 'Código único del estado (ABIERTO, PROGRAMADO, etc.)',
  nombre VARCHAR(50) NOT NULL COMMENT 'Nombre descriptivo del estado',
  descripcion TEXT COMMENT 'Descripción detallada del estado',
  es_final BOOLEAN DEFAULT 0 COMMENT 'Indica si es un estado final (no permite más cambios)',
  permite_edicion BOOLEAN DEFAULT 1 COMMENT 'Indica si permite edición del servicio',
  orden INT DEFAULT 0 COMMENT 'Orden de visualización',
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_codigo (codigo),
  INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
COMMENT='Estados base del sistema para semántica de negocio';

-- Insertar estados base del sistema
INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES
('ABIERTO', 'Abierto', 'Servicio registrado, pendiente de programación o asignación', 0, 1, 1),
('PROGRAMADO', 'Programado', 'Servicio programado para atención en fecha específica', 0, 1, 2),
('ASIGNADO', 'Asignado', 'Servicio asignado a técnico o responsable', 0, 1, 3),
('EN_EJECUCION', 'En Ejecución', 'Servicio en proceso de ejecución o atención', 0, 1, 4),
('FINALIZADO', 'Finalizado', 'Servicio completado técnicamente, pendiente de cierre administrativo', 1, 0, 5),
('CERRADO', 'Cerrado', 'Servicio cerrado administrativamente, proceso completo', 1, 0, 6),
('CANCELADO', 'Cancelado', 'Servicio cancelado o anulado', 1, 0, 7)
ON DUPLICATE KEY UPDATE 
  nombre = VALUES(nombre),
  descripcion = VALUES(descripcion),
  es_final = VALUES(es_final),
  permite_edicion = VALUES(permite_edicion),
  orden = VALUES(orden);

-- Verificar inserción
SELECT 
  codigo,
  nombre,
  CASE WHEN es_final = 1 THEN 'Sí' ELSE 'No' END as es_final,
  CASE WHEN permite_edicion = 1 THEN 'Sí' ELSE 'No' END as permite_edicion,
  orden
FROM estados_base
ORDER BY orden;
