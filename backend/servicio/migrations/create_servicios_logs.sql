-- ============================================================================
-- SCRIPT: create_servicios_logs.sql
-- PROPÓSITO: Tabla para trazabilidad de tiempos por estado
-- FECHA: 2026-02-14
-- ============================================================================

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
    
    -- Foreign Keys
    CONSTRAINT fk_servicios_logs_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    CONSTRAINT fk_servicios_logs_usuario FOREIGN KEY (user_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
