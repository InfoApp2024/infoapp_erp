-- Script de inicialización para el módulo de Inspecciones
-- Creación de tablas, relaciones, triggers e índices

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. Tabla de Sistemas (Catálogo de sistemas de equipos)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE COMMENT 'Nombre del sistema (ej: CHASIS, MOTOR)',
    descripcion TEXT COMMENT 'Descripción detallada del sistema',
    activo TINYINT(1) DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_activo (activo),
    INDEX idx_nombre (nombre)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar sistemas predefinidos si la tabla está vacía
INSERT INTO sistemas (nombre, descripcion)
SELECT * FROM (
    SELECT 'CHASIS', 'Sistema estructural del vehículo o equipo' UNION ALL
    SELECT 'MOTOR', 'Sistema de propulsión y motor' UNION ALL
    SELECT 'TRANSMISIÓN', 'Sistema de transmisión de potencia' UNION ALL
    SELECT 'SISTEMA ELÉCTRICO', 'Sistema eléctrico y electrónico' UNION ALL
    SELECT 'SISTEMA HIDRÁULICO', 'Sistema hidráulico y neumático' UNION ALL
    SELECT 'FRENOS', 'Sistema de frenado' UNION ALL
    SELECT 'SUSPENSIÓN', 'Sistema de suspensión' UNION ALL
    SELECT 'DIRECCIÓN', 'Sistema de dirección' UNION ALL
    SELECT 'REFRIGERACIÓN', 'Sistema de refrigeración' UNION ALL
    SELECT 'ESCAPE', 'Sistema de escape'
) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM sistemas LIMIT 1
);

-- -----------------------------------------------------------------------------
-- 2. Tabla Principal de Inspecciones
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inspecciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    o_inspe VARCHAR(20) NOT NULL UNIQUE COMMENT 'Número de inspección (auto-incrementable)',
    estado_id INT NOT NULL COMMENT 'FK a tabla estados',
    sitio VARCHAR(50) NOT NULL DEFAULT 'PLANTA' COMMENT 'Sitio de inspección',
    fecha_inspe DATE NOT NULL COMMENT 'Fecha de la inspección',
    equipo_id INT NOT NULL COMMENT 'FK a tabla equipos',
    
    -- Campos de auditoría
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT COMMENT 'Usuario que creó el registro',
    updated_by INT COMMENT 'Usuario que actualizó el registro',
    deleted_by INT COMMENT 'Usuario que eliminó el registro',
    deleted_at TIMESTAMP NULL COMMENT 'Soft delete',
    
    -- Índices para optimización
    INDEX idx_o_inspe (o_inspe),
    INDEX idx_estado (estado_id),
    INDEX idx_equipo (equipo_id),
    INDEX idx_fecha (fecha_inspe),
    INDEX idx_sitio (sitio),
    INDEX idx_deleted (deleted_at),
    INDEX idx_created_by (created_by),
    INDEX idx_updated_by (updated_by)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 3. Tabla de Relación: Inspecciones - Inspectores (Muchos a Muchos)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inspecciones_inspectores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL COMMENT 'FK a tabla inspecciones',
    usuario_id INT NOT NULL COMMENT 'FK a tabla usuarios (inspector)',
    rol_inspector VARCHAR(50) DEFAULT 'Inspector' COMMENT 'Rol del inspector (Principal, Asistente, etc.)',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Evitar duplicados
    UNIQUE KEY uk_inspeccion_usuario (inspeccion_id, usuario_id),
    
    -- Índices
    INDEX idx_inspeccion (inspeccion_id),
    INDEX idx_usuario (usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 4. Tabla de Relación: Inspecciones - Sistemas (Muchos a Muchos)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inspecciones_sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL COMMENT 'FK a tabla inspecciones',
    sistema_id INT NOT NULL COMMENT 'FK a tabla sistemas',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    -- Evitar duplicados
    UNIQUE KEY uk_inspeccion_sistema (inspeccion_id, sistema_id),
    
    -- Índices
    INDEX idx_inspeccion (inspeccion_id),
    INDEX idx_sistema (sistema_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 5. Tabla de Actividades de Inspección
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inspecciones_actividades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL COMMENT 'FK a tabla inspecciones',
    actividad_id INT NOT NULL COMMENT 'FK a tabla actividades_estandar',
    autorizada TINYINT(1) DEFAULT 0 COMMENT '1=Autorizada, 0=No autorizada',
    autorizado_por_id INT COMMENT 'FK a usuarios - quien autorizó',
    orden_cliente VARCHAR(100) COMMENT 'Número de orden del cliente (opcional)',
    servicio_id INT COMMENT 'FK a servicios - si se creó servicio desde esta actividad',
    notas TEXT COMMENT 'Notas adicionales sobre la actividad',
    fecha_autorizacion DATETIME NULL COMMENT 'Fecha y hora en que se autorizó la actividad',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT COMMENT 'Usuario que creó el registro',
    updated_by INT COMMENT 'Usuario que actualizó el registro',
    deleted_by INT COMMENT 'Usuario que eliminó el registro',
    deleted_at TIMESTAMP NULL COMMENT 'Soft delete',
    
    -- Evitar duplicados
    UNIQUE KEY uk_inspeccion_actividad (inspeccion_id, actividad_id),
    
    -- Índices
    INDEX idx_inspeccion (inspeccion_id),
    INDEX idx_actividad (actividad_id),
    INDEX idx_autorizada (autorizada),
    INDEX idx_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 6. Tabla de Evidencias (Fotos con comentarios)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS inspecciones_evidencias (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL COMMENT 'FK a tabla inspecciones',
    actividad_id INT COMMENT 'FK a inspecciones_actividades (opcional, para asociar evidencia a actividad específica)',
    ruta_imagen VARCHAR(500) NOT NULL COMMENT 'Ruta de la imagen en el servidor',
    comentario TEXT COMMENT 'Comentario asociado a la evidencia',
    orden INT DEFAULT 0 COMMENT 'Orden de visualización de las fotos',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT COMMENT 'Usuario que subió la evidencia',
    
    -- Índices
    INDEX idx_inspeccion (inspeccion_id),
    INDEX idx_actividad (actividad_id),
    INDEX idx_orden (orden)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 7. Trigger para auto-incrementar o_inspe con formato personalizado
-- -----------------------------------------------------------------------------
DELIMITER $$

DROP TRIGGER IF EXISTS before_insert_inspecciones$$

CREATE TRIGGER before_insert_inspecciones
BEFORE INSERT ON inspecciones
FOR EACH ROW
BEGIN
    DECLARE next_number INT;
    
    -- Obtener el siguiente número
    SELECT COALESCE(MAX(CAST(SUBSTRING(o_inspe, 6) AS UNSIGNED)), 0) + 1 
    INTO next_number
    FROM inspecciones
    WHERE o_inspe LIKE 'INSP-%';
    
    -- Asignar el nuevo o_inspe con formato INSP-0001
    SET NEW.o_inspe = CONCAT('INSP-', LPAD(next_number, 4, '0'));
END$$

DELIMITER ;

-- -----------------------------------------------------------------------------
-- 8. Insertar módulo en tabla de módulos (si existe)
-- -----------------------------------------------------------------------------
-- Solo insertar si la tabla modulos existe
SET @table_exists = (SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_schema = DATABASE() AND table_name = 'modulos');

SET @sql_insert_modulo = IF(@table_exists > 0,
    "INSERT INTO modulos (nombre, descripcion, activo)
     SELECT 'inspecciones', 'Módulo de Inspecciones de Equipos', 1
     WHERE NOT EXISTS (SELECT 1 FROM modulos WHERE nombre = 'inspecciones')",
    "SELECT 'Tabla modulos no existe, omitiendo inserción' AS info");

PREPARE stmt FROM @sql_insert_modulo;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- -----------------------------------------------------------------------------
-- 9. Crear estados iniciales para el módulo de inspecciones (si no existen)
-- -----------------------------------------------------------------------------
-- Solo si las tablas modulos y estados existen
SET @estados_exists = (SELECT COUNT(*) FROM information_schema.tables 
    WHERE table_schema = DATABASE() AND table_name = 'estados');

SET @modulo_id = NULL;

-- Obtener el ID del módulo de inspecciones solo si la tabla existe
SET @sql_get_modulo = IF(@table_exists > 0,
    "SELECT id INTO @modulo_id FROM modulos WHERE nombre = 'inspecciones' LIMIT 1",
    "SELECT NULL INTO @modulo_id");

PREPARE stmt FROM @sql_get_modulo;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- Insertar estados básicos si las tablas existen y el módulo fue creado
SET @sql_insert_estados = IF(@estados_exists > 0 AND @modulo_id IS NOT NULL,
    "INSERT INTO estados (nombre, modulo_id, color, descripcion, orden)
     SELECT * FROM (
         SELECT 'Pendiente', @modulo_id, '#FFA500', 'Inspección pendiente de realizar', 1 UNION ALL
         SELECT 'En Proceso', @modulo_id, '#2196F3', 'Inspección en proceso', 2 UNION ALL
         SELECT 'Completada', @modulo_id, '#4CAF50', 'Inspección completada', 3 UNION ALL
         SELECT 'Aprobada', @modulo_id, '#00C853', 'Inspección aprobada', 4 UNION ALL
         SELECT 'Rechazada', @modulo_id, '#F44336', 'Inspección rechazada', 5
     ) AS tmp
     WHERE NOT EXISTS (SELECT 1 FROM estados WHERE modulo_id = @modulo_id LIMIT 1)",
    "SELECT 'Tabla estados no existe o módulo no creado, omitiendo inserción' AS info");

PREPARE stmt FROM @sql_insert_estados;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET FOREIGN_KEY_CHECKS = 1;

-- Confirmación
SELECT 'Módulo de Inspecciones creado exitosamente' as Resultado;
SELECT COUNT(*) as 'Total Sistemas' FROM sistemas;

-- Contar estados solo si la tabla existe
SET @sql_count_estados = IF(@estados_exists > 0 AND @modulo_id IS NOT NULL,
    "SELECT COUNT(*) as 'Total Estados Inspecciones' FROM estados WHERE modulo_id = @modulo_id",
    "SELECT 0 as 'Total Estados Inspecciones'");

PREPARE stmt FROM @sql_count_estados;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
