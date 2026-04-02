-- =============================================================================
-- MIGRACIÓN: accounting_phase_12_ciclo_auditoria.sql
-- PROPÓSITO: Soporte de ciclos de auditoría por servicio.
-- Cuando un servicio es devuelto a operaciones y re-legalizado, se requiere
-- una nueva auditoría por ciclo. Los registros anteriores se conservan
-- para trazabilidad histórica.
-- =============================================================================

-- 1. Agregar columna 'ciclo' a la tabla de auditorías
ALTER TABLE fac_auditorias_servicio
    ADD COLUMN IF NOT EXISTS ciclo INT NOT NULL DEFAULT 1
        COMMENT 'Número de ciclo de gestión financiera. Incrementa al devolver a operaciones.';

-- 2. Crear tabla de control de ciclos (sobrevive al borrado del snapshot)
CREATE TABLE IF NOT EXISTS fac_audit_ciclos (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id  INT NOT NULL,
    ciclo_actual INT NOT NULL DEFAULT 1,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_servicio (servicio_id),
    CONSTRAINT fk_ciclo_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Lleva el contador de ciclos de gestión financiera por servicio.';

-- 3. Índice compuesto para búsquedas ciclo-precisas
ALTER TABLE fac_auditorias_servicio
    ADD INDEX IF NOT EXISTS idx_servicio_ciclo (servicio_id, ciclo);

SELECT 'Migración accounting_phase_12_ciclo_auditoria completada' AS Resultado;
