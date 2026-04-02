-- Script de inicialización para el módulo de Geocercas

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. Tabla de Geocercas (Configuración de lugares)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS geocercas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL COMMENT 'Nombre del lugar (ej. Sede Norte)',
    latitud DECIMAL(10, 8) NOT NULL COMMENT 'Coordenada Latitud',
    longitud DECIMAL(11, 8) NOT NULL COMMENT 'Coordenada Longitud',
    radio INT NOT NULL DEFAULT 100 COMMENT 'Radio en metros',
    estado TINYINT(1) DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. Tabla de Registros de Geocerca (Historial de ingresos/salidas)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS registros_geocerca (
    id INT AUTO_INCREMENT PRIMARY KEY,
    geocerca_id INT NOT NULL,
    usuario_id INT NOT NULL,
    fecha_ingreso DATETIME NOT NULL COMMENT 'Fecha y hora de entrada servidor',
    fecha_salida DATETIME NULL COMMENT 'Fecha y hora de salida servidor',
    foto_ingreso VARCHAR(255) NULL COMMENT 'Ruta foto entrada',
    foto_salida VARCHAR(255) NULL COMMENT 'Ruta foto salida',
    fecha_captura_ingreso DATETIME NULL COMMENT 'Fecha real captura entrada (dispositivo)',
    fecha_captura_salida DATETIME NULL COMMENT 'Fecha real captura salida (dispositivo)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT fk_registros_geocerca FOREIGN KEY (geocerca_id) REFERENCES geocercas(id),
    CONSTRAINT fk_registros_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
