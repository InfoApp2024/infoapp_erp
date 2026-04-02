-- =============================================================================
-- MÓDULO: Core Fields / Campos Adicionales
-- PROPÓSITO: Campos dinámicos creados por el usuario para módulos del sistema.
-- =============================================================================

SET NAMES utf8mb4;

-- 1. Definición de campos adicionales (por módulo y estado)
CREATE TABLE IF NOT EXISTS campos_adicionales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_campo VARCHAR(100) NOT NULL,
    etiqueta VARCHAR(150),
    tipo_campo ENUM('texto', 'numero', 'fecha', 'seleccion', 'booleano', 'archivo', 'imagen') DEFAULT 'texto',
    modulo VARCHAR(50) NOT NULL COMMENT 'servicio, equipo, cliente, etc.',
    estado_id INT NULL COMMENT 'Si no es null, solo se muestra en ese estado',
    opciones TEXT NULL COMMENT 'JSON de opciones para tipo seleccion',
    obligatorio TINYINT(1) DEFAULT 0,
    orden INT DEFAULT 0,
    activo TINYINT(1) DEFAULT 1,
    creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_campo_modulo (nombre_campo, modulo),
    INDEX idx_modulo (modulo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Valores de los campos adicionales por registro (V2 Typed)
CREATE TABLE IF NOT EXISTS valores_campos_adicionales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    campo_id INT NOT NULL,
    servicio_id INT NOT NULL COMMENT 'ID del registro al que pertenece (servicio, equipo, etc.)',
    valor_texto TEXT,
    valor_numero DECIMAL(18,2),
    valor_fecha DATE,
    valor_hora TIME,
    valor_datetime DATETIME,
    valor_archivo VARCHAR(500),
    valor_booleano TINYINT(1),
    tipo_campo VARCHAR(50),
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (campo_id) REFERENCES campos_adicionales(id) ON DELETE CASCADE,
    INDEX idx_campo_registro (campo_id, servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Archivos adjuntos en campos adicionales de tipo archivo/imagen
CREATE TABLE IF NOT EXISTS archivos_campos_adicionales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    campo_id INT NOT NULL,
    registro_id INT NOT NULL,
    nombre_archivo VARCHAR(255) NOT NULL,
    ruta_archivo VARCHAR(500) NOT NULL,
    mime_type VARCHAR(100),
    tamano_bytes INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (campo_id) REFERENCES campos_adicionales(id) ON DELETE CASCADE,
    INDEX idx_campo_archivo (campo_id, registro_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Historial de cambios en valores de campos adicionales
CREATE TABLE IF NOT EXISTS historial_valores_campos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    campo_id INT NOT NULL,
    registro_id INT NOT NULL,
    valor_anterior TEXT,
    valor_nuevo TEXT,
    usuario_id INT,
    fecha TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_historial_campo (campo_id, registro_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
