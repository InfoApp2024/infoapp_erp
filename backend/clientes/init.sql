-- Script de inicialización para el módulo de Clientes
-- Corrección: Elimina la vista 'clientes' si existe antes de crear la tabla

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Eliminar la vista 'clientes' si existe para liberar el nombre
DROP VIEW IF EXISTS clientes;

-- -----------------------------------------------------------------------------
-- 2. Tabla de Ciudades (Maestra)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ciudades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    departamento VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Insertar ciudades principales de Colombia si la tabla está vacía
INSERT INTO ciudades (nombre, departamento)
SELECT * FROM (
    SELECT 'Bogotá', 'Cundinamarca' UNION ALL
    SELECT 'Medellín', 'Antioquia' UNION ALL
    SELECT 'Cali', 'Valle del Cauca' UNION ALL
    SELECT 'Barranquilla', 'Atlántico' UNION ALL
    SELECT 'Cartagena', 'Bolívar' UNION ALL
    SELECT 'Bucaramanga', 'Santander' UNION ALL
    SELECT 'Pereira', 'Risaralda' UNION ALL
    SELECT 'Manizales', 'Caldas' UNION ALL
    SELECT 'Cúcuta', 'Norte de Santander' UNION ALL
    SELECT 'Ibagué', 'Tolima'
) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM ciudades LIMIT 1
);

-- -----------------------------------------------------------------------------
-- 3. Tabla de Clientes
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tipo_persona ENUM('Natural', 'Juridica') NOT NULL DEFAULT 'Natural',
    documento_nit VARCHAR(20) NOT NULL UNIQUE COMMENT 'Cédula, NIT, RUC o DNI',
    nombre_completo VARCHAR(150) NOT NULL COMMENT 'Nombre o Razón Social',
    email VARCHAR(100) COMMENT 'Para envío automático',
    telefono_principal VARCHAR(20) COMMENT 'WhatsApp o móvil',
    telefono_secundario VARCHAR(20) COMMENT 'Fijo u oficina',
    direccion TEXT COMMENT 'Dirección de cobro/visita',
    ciudad_id INT COMMENT 'FK a tabla ciudades',
    limite_credito DECIMAL(10,2) DEFAULT 0.00,
    perfil VARCHAR(100) COMMENT 'Nombre del perfil principal',
    estado TINYINT(1) DEFAULT 1 COMMENT '1=Activo, 0=Inactivo',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    id_user INT COMMENT 'Usuario que creó el registro',
    
    CONSTRAINT fk_clientes_ciudad FOREIGN KEY (ciudad_id) REFERENCES ciudades(id),
    CONSTRAINT fk_clientes_usuario FOREIGN KEY (id_user) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;
