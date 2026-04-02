

CREATE TABLE IF NOT EXISTS fac_config_consecutivos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    prefijo VARCHAR(50) NOT NULL,
    valor_actual INT NOT NULL DEFAULT 1,
    descripcion VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Inicializar el consecutivo solicitado por el usuario (#3.13 / Error 409)
INSERT INTO fac_config_consecutivos (prefijo, valor_actual, descripcion) 
VALUES ('', 1, 'Consecutivo manual para Factus Reference Code')
ON DUPLICATE KEY UPDATE valor_actual = 1;
