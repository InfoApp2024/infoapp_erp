-- ============================================================
-- Migración: Módulo de Auditoría Financiera (SoD)
-- Fecha: 2026-03-01
-- ============================================================

-- 1. Añadir columna es_auditor a usuarios
-- Un auditor puede ser cualquier rol (admin, técnico, etc.)
ALTER TABLE usuarios
  ADD COLUMN IF NOT EXISTS es_auditor TINYINT(1) NOT NULL DEFAULT 0
  COMMENT 'Si 1, el usuario puede auditar servicios financieros antes de su legalización';

-- 2. Crear tabla de auditorías financieras por servicio
CREATE TABLE IF NOT EXISTS fac_auditorias_servicio (
  id            INT          NOT NULL AUTO_INCREMENT,
  servicio_id   INT          NOT NULL COMMENT 'FK a fac_control_servicios.id',
  auditor_id    INT          NOT NULL COMMENT 'FK a usuarios.id (debe tener es_auditor=1)',
  fecha_auditoria DATETIME   NOT NULL DEFAULT CURRENT_TIMESTAMP,
  comentario    TEXT         NULL     COMMENT 'Observaciones del auditor',
  created_at    DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,

  PRIMARY KEY (id),
  INDEX idx_servicio (servicio_id),
  INDEX idx_auditor  (auditor_id),

  CONSTRAINT fk_auditoria_servicio
    FOREIGN KEY (servicio_id)
    REFERENCES fac_control_servicios(id)
    ON DELETE CASCADE ON UPDATE CASCADE,

  CONSTRAINT fk_auditoria_auditor
    FOREIGN KEY (auditor_id)
    REFERENCES usuarios(id)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
  COMMENT='Registro de auditorías financieras realizadas sobre servicios antes de legalización';
