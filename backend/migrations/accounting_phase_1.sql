-- ============================================================================
-- SCRIPT: Migración Fase 1 - Módulo Contable
-- PROPÓSITO: Agregar estado LEGALIZADO y tabla de Snapshot
-- ============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Agregar Estado Base LEGALIZADO
INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) 
VALUES ('LEGALIZADO', 'Legalizado', 'Servicio con snapshot de valores listo para facturar', 0, 0, 6)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), orden=6;

-- Ajustar orden de estados base posteriores
UPDATE estados_base SET orden = 7 WHERE codigo = 'CERRADO';
UPDATE estados_base SET orden = 8 WHERE codigo = 'CANCELADO';

-- 2. Agregar Estado de Proceso Legalizado (IDEMPOTENTE)
-- Solo insertar si no existe ya un estado mapeado a LEGALIZADO
INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre)
SELECT 'Legalizado', '#009688', 'servicio', 'LEGALIZADO', 55, 0
FROM (SELECT 1) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM estados_proceso 
    WHERE modulo = 'servicio' AND estado_base_codigo = 'LEGALIZADO'
);

-- 3. Tabla de Snapshot (Capa Comercial)
CREATE TABLE IF NOT EXISTS fac_control_servicios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    valor_snapshot DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    total_facturado DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    estado_comercial_cache ENUM('NO_FACTURADO', 'PARCIAL', 'TOTAL', 'ANULADO') DEFAULT 'NO_FACTURADO',
    fecha_legalizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (servicio_id) REFERENCES servicios(id),
    UNIQUE KEY idx_unique_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Actualizar Transiciones
-- Eliminar transición directa Finalizado -> Cerrado para obligar el paso por Legalizado
DELETE FROM transiciones_estado 
WHERE modulo = 'servicio' 
AND estado_origen_id IN (SELECT id FROM estados_proceso WHERE estado_base_codigo = 'FINALIZADO')
AND estado_destino_id IN (SELECT id FROM estados_proceso WHERE estado_base_codigo = 'CERRADO');

-- Nueva transición: Finalizado -> Legalizado
INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
SELECT e1.id, e2.id, 'Legalizar', 'servicio', 'MANUAL'
FROM estados_proceso e1, estados_proceso e2
WHERE e1.estado_base_codigo = 'FINALIZADO' AND e2.estado_base_codigo = 'LEGALIZADO'
AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

-- Nueva transición: Legalizado -> Cerrado
INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo, trigger_code)
SELECT e1.id, e2.id, 'Cerrar', 'servicio', 'MANUAL'
FROM estados_proceso e1, estados_proceso e2
WHERE e1.estado_base_codigo = 'LEGALIZADO' AND e2.estado_base_codigo = 'CERRADO'
AND e1.modulo = 'servicio' AND e2.modulo = 'servicio';

SET FOREIGN_KEY_CHECKS = 1;
