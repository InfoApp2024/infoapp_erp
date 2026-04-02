-- =============================================================================
-- MÓDULO: Firma Digital
-- PROPÓSITO: Tabla de firmas capturadas por servicios de campo.
-- =============================================================================

SET NAMES utf8mb4;

CREATE TABLE IF NOT EXISTS firmas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_servicio INT NOT NULL,
    id_staff_entrega INT NOT NULL COMMENT 'FK a usuarios.id (técnico que entrega)',
    id_funcionario_recibe INT NOT NULL COMMENT 'FK a funcionario.id (cliente que recibe)',
    firma_staff_base64 LONGTEXT NOT NULL,
    firma_funcionario_base64 LONGTEXT NOT NULL,
    nota_entrega TEXT NULL,
    nota_recepcion TEXT NULL,
    participantes_servicio TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_servicio (id_servicio),
    FOREIGN KEY (id_servicio) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (id_staff_entrega) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
