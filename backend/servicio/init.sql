-- =============================================================================
-- MÓDULO: Servicio (Log de trazabilidad y Fotos)
-- PROPÓSITO: Tablas de auditoría y evidencia fotográfica de servicios.
-- =============================================================================

SET NAMES utf8mb4;

-- 1. Log de trazabilidad de cambios de estado
CREATE TABLE IF NOT EXISTS servicios_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    from_status_id INT NULL COMMENT 'Estado anterior',
    to_status_id INT NOT NULL COMMENT 'Estado al que se movió',
    user_id INT NOT NULL COMMENT 'Usuario que realizó el cambio',
    timestamp DATETIME NOT NULL COMMENT 'Fecha y hora del movimiento',
    duration_seconds INT DEFAULT 0 COMMENT 'Duración en segundos del estado ANTERIOR',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    INDEX idx_servicio_log (servicio_id),
    INDEX idx_timestamp (timestamp),
    
    CONSTRAINT fk_servicios_logs_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    CONSTRAINT fk_servicios_logs_usuario FOREIGN KEY (user_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Fotos adjuntas a un servicio (antes/después)
CREATE TABLE IF NOT EXISTS fotos_servicio (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    tipo_foto ENUM('antes', 'despues') NOT NULL DEFAULT 'antes',
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500) NOT NULL,
    descripcion TEXT NULL,
    orden_visualizacion INT DEFAULT 1,
    tamaño_bytes INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_servicio_foto (servicio_id),
    FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Desbloqueos de repuestos por servicio
CREATE TABLE IF NOT EXISTS servicios_desbloqueos_repuestos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    usuario_id INT NOT NULL,
    motivo TEXT,
    usado TINYINT(1) DEFAULT 0 COMMENT '1=Si, 0=No',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
