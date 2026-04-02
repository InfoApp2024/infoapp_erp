-- accounting_phase_2_log.sql
-- Creación de la tabla de auditoría de causación (Log Transitorio)
-- Autor: Senior Developer / Architect

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Tabla: fin_asientos_log
-- Almacena la previsualización confirmada de la causación antes de la factura oficial
CREATE TABLE IF NOT EXISTS fin_asientos_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    p_cuenta VARCHAR(20) NOT NULL, -- Código de la cuenta del PUC
    tipo ENUM('DEBITO', 'CREDITO') NOT NULL,
    valor DECIMAL(18,2) NOT NULL,
    referencia VARCHAR(100), -- Ej: CAUSACION-OT-1280
    creado_por INT NOT NULL,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_servicio (servicio_id),
    INDEX idx_cuenta (p_cuenta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;
