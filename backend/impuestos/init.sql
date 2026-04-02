CREATE TABLE IF NOT EXISTS impuestos_config (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_impuesto VARCHAR(100) NOT NULL,
    tipo_impuesto ENUM('IVA', 'RETEFUENTE', 'RETEICA', 'RETEIVA', 'AUTORETEFUENTE') NOT NULL,
    codigo_ciiu VARCHAR(20) DEFAULT NULL COMMENT 'Vincula tarifa a actividad economica',
    porcentaje DECIMAL(5, 2) NOT NULL,
    base_minima_uvt DECIMAL(10, 2) DEFAULT 0,
    base_minima_pesos DECIMAL(15, 2) DEFAULT 0,
    descripcion TEXT,
    estado TINYINT(1) DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
