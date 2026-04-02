-- backend/setup/sql/core_base.sql
-- Definitive baseline schema for InfoApp Master Setup
-- Reconstructed from module controllers and SQL fragments.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Table: modulos
CREATE TABLE IF NOT EXISTS modulos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT,
    activo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Table: usuarios
CREATE TABLE IF NOT EXISTS usuarios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    NOMBRE_USER VARCHAR(50) NOT NULL UNIQUE,
    CONTRASEÑA VARCHAR(255) NOT NULL,
    TIPO_ROL ENUM('admin', 'administrador', 'gerente', 'rh', 'tecnico', 'cliente', 'colaborador') NOT NULL,
    NOMBRE_CLIENTE VARCHAR(150),
    CORREO VARCHAR(100),
    NIT VARCHAR(20),
    ESTADO_USER ENUM('activo', 'inactivo') DEFAULT 'activo',
    ID_REGISTRO VARCHAR(50) DEFAULT 'dev',
    URL_FOTO VARCHAR(500),
    TELEFONO VARCHAR(20),
    DIRECCION TEXT,
    FECHA_NACIMIENTO DATE,
    TIPO_IDENTIFICACION VARCHAR(20),
    NUMERO_IDENTIFICACION VARCHAR(20),
    CODIGO_STAFF VARCHAR(20),
    funcionario_id INT,
    CONTACTO_EMERGENCIA_NOMBRE VARCHAR(150),
    CONTACTO_EMERGENCIA_TELEFONO VARCHAR(20),
    es_auditor TINYINT(1) DEFAULT 0,
    can_edit_closed_ops TINYINT(1) DEFAULT 0,
    regimen_tributario VARCHAR(100),
    FECHA_CONTRATACION DATE,
    ID_POSICION INT,
    ID_DEPARTAMENTO INT,
    SALARIO DECIMAL(18,2),
    USUARIO_ACTUALIZACION INT NULL,
    ID_ESPECIALIDAD INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_estado (ESTADO_USER),
    INDEX idx_rol (TIPO_ROL),
    FOREIGN KEY (USUARIO_ACTUALIZACION) REFERENCES usuarios(id),
    FOREIGN KEY (ID_ESPECIALIDAD) REFERENCES especialidades(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Table: user_permissions
CREATE TABLE IF NOT EXISTS user_permissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    module VARCHAR(50) NOT NULL,
    action VARCHAR(50) NOT NULL,
    allowed TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    UNIQUE KEY uk_user_module_action (user_id, module, action)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 4. Table: departments
CREATE TABLE IF NOT EXISTS departments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    manager_id INT NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    INDEX idx_name (name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 5. Table: positions
CREATE TABLE IF NOT EXISTS positions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    title VARCHAR(100) NOT NULL,
    description TEXT,
    department_id INT NOT NULL,
    min_salary DECIMAL(10,2) NULL,
    max_salary DECIMAL(10,2) NULL,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP NULL,
    INDEX idx_department (department_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6. Table: especialidades
CREATE TABLE IF NOT EXISTS especialidades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom_especi VARCHAR(100) NOT NULL,
    valor_hr DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 7. Table: staff
CREATE TABLE IF NOT EXISTS staff (
    id INT AUTO_INCREMENT PRIMARY KEY,
    staff_code VARCHAR(20) UNIQUE,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    department_id INT,
    position_id INT,
    id_especialidad INT,
    hire_date DATE,
    birth_date DATE,
    identification_type VARCHAR(20) DEFAULT 'dni',
    identification_number VARCHAR(20) NOT NULL,
    salary DECIMAL(10,2),
    address TEXT,
    emergency_contact_name VARCHAR(150),
    emergency_contact_phone VARCHAR(20),
    photo_url VARCHAR(500),
    is_active TINYINT(1) DEFAULT 1,
    deleted_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (department_id) REFERENCES departments(id),
    FOREIGN KEY (position_id) REFERENCES positions(id),
    FOREIGN KEY (id_especialidad) REFERENCES especialidades(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 8. Table: equipos
CREATE TABLE IF NOT EXISTS equipos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    modelo VARCHAR(100),
    marca VARCHAR(100),
    placa VARCHAR(50) NOT NULL,
    codigo VARCHAR(50),
    ciudad VARCHAR(100),
    planta VARCHAR(100),
    linea_prod VARCHAR(100),
    nombre_empresa VARCHAR(150) NOT NULL,
    cliente_id INT,
    usuario_registro VARCHAR(50),
    activo TINYINT(1) DEFAULT 1,
    estado_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_placa (placa),
    INDEX idx_empresa (nombre_empresa)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 9. Table: inventory_categories
CREATE TABLE IF NOT EXISTS inventory_categories (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    parent_id INT NULL,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (parent_id) REFERENCES inventory_categories(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 10. Table: suppliers
CREATE TABLE IF NOT EXISTS suppliers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    contact_person VARCHAR(100),
    email VARCHAR(100),
    phone VARCHAR(20),
    address TEXT,
    tax_id VARCHAR(20),
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 11. Table: inventory_items
CREATE TABLE IF NOT EXISTS inventory_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    description TEXT,
    category_id INT,
    item_type VARCHAR(50),
    brand VARCHAR(100),
    model VARCHAR(100),
    part_number VARCHAR(100),
    current_stock INT DEFAULT 0,
    minimum_stock INT DEFAULT 0,
    maximum_stock INT DEFAULT 0,
    unit_of_measure VARCHAR(50) DEFAULT 'unidad',
    initial_cost DECIMAL(18,2) DEFAULT 0.00,
    unit_cost DECIMAL(18,2) DEFAULT 0.00,
    average_cost DECIMAL(18,2) DEFAULT 0.00,
    last_cost DECIMAL(18,2) DEFAULT 0.00,
    location VARCHAR(100),
    shelf VARCHAR(50),
    bin VARCHAR(50),
    barcode VARCHAR(100),
    qr_code VARCHAR(100),
    supplier_id INT,
    created_by INT,
    is_active TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (category_id) REFERENCES inventory_categories(id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(id),
    FOREIGN KEY (created_by) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 12. Table: inventory_movements
CREATE TABLE IF NOT EXISTS inventory_movements (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inventory_item_id INT NOT NULL,
    movement_type ENUM('entrada', 'salida', 'ajuste') NOT NULL,
    movement_reason VARCHAR(100),
    quantity INT NOT NULL,
    previous_stock INT NOT NULL,
    new_stock INT NOT NULL,
    unit_cost DECIMAL(18,2),
    reference_type VARCHAR(50),  -- 'service', 'audit', etc.
    reference_id INT,             -- id del objeto de referencia
    notes TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id) ON DELETE CASCADE,
    FOREIGN KEY (created_by) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 13. Table: estados_base
CREATE TABLE IF NOT EXISTS estados_base (
    codigo VARCHAR(50) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT,
    es_final TINYINT(1) DEFAULT 0,
    permite_edicion TINYINT(1) DEFAULT 1,
    orden INT DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 14. Table: estados_proceso
CREATE TABLE IF NOT EXISTS estados_proceso (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_estado VARCHAR(100) NOT NULL,
    color VARCHAR(20) DEFAULT '#000000',
    modulo VARCHAR(50) NOT NULL,
    estado_base_codigo VARCHAR(50),
    orden INT DEFAULT 0,
    bloquea_cierre TINYINT(1) DEFAULT 0,
    FOREIGN KEY (estado_base_codigo) REFERENCES estados_base(codigo),
    UNIQUE KEY uk_nombre_modulo (nombre_estado, modulo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15. Table: transiciones_estado
CREATE TABLE IF NOT EXISTS transiciones_estado (
    id INT AUTO_INCREMENT PRIMARY KEY,
    estado_origen_id INT NOT NULL,
    estado_destino_id INT NOT NULL,
    nombre VARCHAR(100),
    modulo VARCHAR(50) NOT NULL,
    trigger_code VARCHAR(50),
    FOREIGN KEY (estado_origen_id) REFERENCES estados_proceso(id),
    FOREIGN KEY (estado_destino_id) REFERENCES estados_proceso(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 15.5. Table: sistemas
CREATE TABLE IF NOT EXISTS sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion TEXT,
    activo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 16. Table: servicios
CREATE TABLE IF NOT EXISTS servicios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    o_servicio INT UNIQUE,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_ingreso TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    orden_cliente VARCHAR(100),
    autorizado_por INT,
    tipo_mantenimiento VARCHAR(50),
    centro_costo VARCHAR(100),
    id_equipo INT,
    nombre_emp VARCHAR(150),
    placa VARCHAR(50),
    estado INT,
    suministraron_repuestos TINYINT(1) DEFAULT 0,
    fotos_confirmadas TINYINT(1) DEFAULT 0,
    firma_confirmada TINYINT(1) DEFAULT 0,
    personal_confirmado TINYINT(1) DEFAULT 0,
    fecha_finalizacion TIMESTAMP NULL,
    anular_servicio TINYINT(1) DEFAULT 0,
    razon TEXT,
    actividad_id INT,
    responsable_id INT,
    usuario_creador INT,
    usuario_ultima_actualizacion INT,
    cliente_id INT,
    funcionario_id INT,
    cant_hora DECIMAL(10,2),
    num_tecnicos INT,
    estado_comercial VARCHAR(50),
    es_finalizado TINYINT(1) DEFAULT 0,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    deleted_by INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (estado) REFERENCES estados_proceso(id),
    FOREIGN KEY (id_equipo) REFERENCES equipos(id),
    FOREIGN KEY (usuario_creador) REFERENCES usuarios(id),
    FOREIGN KEY (usuario_ultima_actualizacion) REFERENCES usuarios(id),
    FOREIGN KEY (responsable_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 17. Table: operaciones (Operaciones asociadas a servicios)
CREATE TABLE IF NOT EXISTS operaciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    descripcion TEXT NOT NULL,
    is_master TINYINT(1) DEFAULT 0 COMMENT '1 = Operación maestra, no eliminable',
    fecha_inicio DATETIME NULL,
    fecha_fin DATETIME NULL,
    fecha_completado DATETIME NULL,
    estado VARCHAR(50) DEFAULT 'PENDIENTE',
    tecnico_responsable_id INT NULL,
    observaciones TEXT NULL,
    actividad_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_servicio_id (servicio_id),
    FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (tecnico_responsable_id) REFERENCES usuarios(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 18. Table: servicio_repuestos (Repuestos usados en una operación)
CREATE TABLE IF NOT EXISTS servicio_repuestos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    operacion_id INT NULL,
    inventory_item_id INT NULL,
    nombre_repuesto VARCHAR(255) NOT NULL,
    referencia VARCHAR(100),
    cantidad INT NOT NULL DEFAULT 1,
    costo_unitario DECIMAL(18,2) DEFAULT 0,
    costo_total DECIMAL(18,2) DEFAULT 0,
    notas TEXT,
    usuario_asigno INT NULL,
    fecha_asignacion DATETIME NULL,
    suministrado_por ENUM('EMPRESA', 'CLIENTE') DEFAULT 'EMPRESA',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (operacion_id) REFERENCES operaciones(id) ON DELETE SET NULL,
    FOREIGN KEY (usuario_asigno) REFERENCES usuarios(id) ON DELETE SET NULL,
    INDEX idx_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 19. Table: servicio_staff (Personal asignado a una operación)
CREATE TABLE IF NOT EXISTS servicio_staff (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    operacion_id INT NULL,
    staff_id INT NULL,
    usuario_id INT NULL,
    rol VARCHAR(100) DEFAULT 'Técnico',
    horas_trabajadas DECIMAL(10,2) DEFAULT 0,
    costo_hora DECIMAL(18,2) DEFAULT 0,
    asignado_por INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (operacion_id) REFERENCES operaciones(id) ON DELETE SET NULL,
    FOREIGN KEY (staff_id) REFERENCES staff(id) ON DELETE SET NULL,
    FOREIGN KEY (asignado_por) REFERENCES usuarios(id) ON DELETE SET NULL,
    INDEX idx_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 20. Table: departamentos (Geografía Colombia)
CREATE TABLE IF NOT EXISTS departamentos (
    id INT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21. Table: ciudades (Municipios Colombia)
CREATE TABLE IF NOT EXISTS ciudades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo VARCHAR(10),
    nombre VARCHAR(200) NOT NULL,
    departamento VARCHAR(150),
    departamento_id INT,
    FOREIGN KEY (departamento_id) REFERENCES departamentos(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 21.5. Table: clientes
CREATE TABLE IF NOT EXISTS clientes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    tipo_persona ENUM('Natural', 'Juridica') NOT NULL DEFAULT 'Natural',
    documento_nit VARCHAR(20) NOT NULL UNIQUE COMMENT 'Cédula, NIT, RUC o DNI',
    dv VARCHAR(10) NULL,
    nombre_completo VARCHAR(150) NOT NULL COMMENT 'Nombre o Razón Social',
    email VARCHAR(100),
    email_facturacion VARCHAR(150) NULL,
    telefono_principal VARCHAR(20),
    telefono_secundario VARCHAR(20),
    direccion TEXT,
    ciudad_id INT,
    limite_credito DECIMAL(10,2) DEFAULT 0.00,
    perfil VARCHAR(100),
    regimen_tributario VARCHAR(100) DEFAULT 'No Responsable de IVA',
    responsabilidad_fiscal_id VARCHAR(50) DEFAULT 'R-99-PN',
    codigo_ciiu VARCHAR(20) NULL,
    es_agente_retenedor TINYINT(1) DEFAULT 0,
    es_autorretenedor TINYINT(1) DEFAULT 0,
    es_gran_contribuyente TINYINT(1) DEFAULT 0,
    estado TINYINT(1) DEFAULT 1,
    id_user INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (ciudad_id) REFERENCES ciudades(id),
    FOREIGN KEY (id_user) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 22. Table: app_settings (Configuración global del sistema)
CREATE TABLE IF NOT EXISTS app_settings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    setting_key VARCHAR(100) NOT NULL UNIQUE,
    setting_value TEXT,
    description VARCHAR(255),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 23. Table: plantillas (Plantillas PDF del sistema)
CREATE TABLE IF NOT EXISTS plantillas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    tipo VARCHAR(50) NULL COMMENT 'cotizacion, orden_trabajo, reporte, etc.',
    contenido_html LONGTEXT,
    modulo VARCHAR(50) DEFAULT NULL,
    cliente_id INT NULL,
    es_general TINYINT(1) DEFAULT 1,
    usuario_creador INT NULL,
    activo TINYINT(1) DEFAULT 1,
    fecha_creacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    fecha_actualizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    FOREIGN KEY (usuario_creador) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24. Table: config_branding (Datos de empresa/branding del sistema - Anteriormente funcionario)
CREATE TABLE IF NOT EXISTS config_branding (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_empresa VARCHAR(150),
    nit VARCHAR(30),
    regimen VARCHAR(100),
    representante VARCHAR(150),
    telefono VARCHAR(30),
    email VARCHAR(100),
    direccion TEXT,
    ciudad VARCHAR(100),
    pais VARCHAR(50) DEFAULT 'Colombia',
    logo_url VARCHAR(500),
    firma_url VARCHAR(500),
    pie_pagina TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 24.5. Table: funcionario (Contactos/Personas de Clientes)
CREATE TABLE IF NOT EXISTS funcionario (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(150) NOT NULL,
    cargo VARCHAR(100),
    empresa VARCHAR(150),
    telefono VARCHAR(50),
    correo VARCHAR(100),
    cliente_id INT,
    activo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 25. Table: branding (Configuración de marca del sistema)
CREATE TABLE IF NOT EXISTS branding (
    id INT AUTO_INCREMENT PRIMARY KEY,
    empresa_nombre VARCHAR(150),
    empresa_nit VARCHAR(30),
    empresa_logo TEXT,
    empresa_color_primario VARCHAR(20) DEFAULT '#1976D2',
    empresa_color_secundario VARCHAR(20) DEFAULT '#424242',
    empresa_email VARCHAR(100),
    empresa_telefono VARCHAR(30),
    empresa_direccion TEXT,
    empresa_ciudad VARCHAR(100),
    empresa_pais VARCHAR(50) DEFAULT 'Colombia',
    empresa_pie_pagina TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 26. Table: actividades_estandar (Plantillas de actividades para servicios)
CREATE TABLE IF NOT EXISTS actividades_estandar (
    id INT AUTO_INCREMENT PRIMARY KEY,
    actividad VARCHAR(255) NOT NULL,
    activo TINYINT(1) DEFAULT 1,
    cant_hora DECIMAL(10,2) DEFAULT 0.00,
    num_tecnicos INT DEFAULT 1,
    id_user INT NULL,
    sistema_id INT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_activo (activo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 27. Table: service_inventory_items (Inventario consumido por servicio - relación N:N)
CREATE TABLE IF NOT EXISTS service_inventory_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    service_id INT NOT NULL,
    inventory_item_id INT NOT NULL,
    quantity_used INT NOT NULL,
    unit_cost DECIMAL(10,2) DEFAULT 0.00,
    total_cost DECIMAL(10,2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (service_id) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (inventory_item_id) REFERENCES inventory_items(id),
    INDEX idx_service (service_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 28. Table: campos_adicionales
CREATE TABLE IF NOT EXISTS campos_adicionales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre_campo VARCHAR(100) NOT NULL,
    etiqueta VARCHAR(150),
    tipo_campo ENUM('texto', 'numero', 'fecha', 'seleccion', 'booleano', 'archivo', 'imagen') DEFAULT 'texto',
    modulo VARCHAR(50) NOT NULL,
    estado_id INT NULL,
    estado_mostrar INT DEFAULT 1,
    opciones TEXT NULL,
    requerido TINYINT(1) DEFAULT 0,
    orden INT DEFAULT 0,
    activo TINYINT(1) DEFAULT 1,
    creado TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_campo_modulo (nombre_campo, modulo),
    INDEX idx_modulo (modulo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 29. Table: valores_campos_adicionales (V2 Typed)
CREATE TABLE IF NOT EXISTS valores_campos_adicionales (
    id INT AUTO_INCREMENT PRIMARY KEY,
    campo_id INT NOT NULL,
    servicio_id INT NOT NULL COMMENT 'ID del registro al que pertenece (Históricamente servicio_id)',
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

-- 30. Table: archivos_campos_adicionales
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

-- 31. Table: historial_valores_campos
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

-- 32. Table: notas
CREATE TABLE IF NOT EXISTS notas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_servicio INT NOT NULL,
    nota LONGTEXT NOT NULL,
    fecha DATE NOT NULL,
    hora TIME NOT NULL,
    usuario VARCHAR(255) NOT NULL,
    usuario_id INT NOT NULL,
    es_automatica TINYINT(1) DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    INDEX idx_servicio (id_servicio),
    INDEX idx_usuario (usuario_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 33. Table: firmas
CREATE TABLE IF NOT EXISTS firmas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    id_servicio INT NOT NULL,
    id_staff_entrega INT NOT NULL,
    id_funcionario_recibe INT NOT NULL,
    firma_staff_base64 LONGTEXT NOT NULL,
    firma_funcionario_base64 LONGTEXT NOT NULL,
    nota_entrega TEXT NULL,
    nota_recepcion TEXT NULL,
    participantes_servicio TEXT NULL,
    created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_servicio (id_servicio),
    FOREIGN KEY (id_servicio) REFERENCES servicios(id) ON DELETE CASCADE,
    FOREIGN KEY (id_staff_entrega) REFERENCES usuarios(id),
    FOREIGN KEY (id_funcionario_recibe) REFERENCES funcionario(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 27.5. Table: servicios_desbloqueos_repuestos (Desbloqueos de repuestos por servicio)
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

-- 34. Table: inspecciones
CREATE TABLE IF NOT EXISTS inspecciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    o_inspe VARCHAR(20) NOT NULL UNIQUE,
    estado_id INT NOT NULL,
    sitio VARCHAR(50) NOT NULL DEFAULT 'PLANTA',
    fecha_inspe DATE NOT NULL,
    equipo_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    updated_by INT,
    deleted_by INT,
    deleted_at TIMESTAMP NULL,
    INDEX idx_o_inspe (o_inspe),
    INDEX idx_estado (estado_id),
    INDEX idx_equipo (equipo_id),
    INDEX idx_deleted (deleted_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 35. Table: inspecciones_inspectores
CREATE TABLE IF NOT EXISTS inspecciones_inspectores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    usuario_id INT NOT NULL,
    rol_inspector VARCHAR(50) DEFAULT 'Inspector',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_inspeccion_usuario (inspeccion_id, usuario_id),
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 36. Table: inspecciones_sistemas
CREATE TABLE IF NOT EXISTS inspecciones_sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    sistema_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uk_inspeccion_sistema (inspeccion_id, sistema_id),
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (sistema_id) REFERENCES sistemas(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 37. Table: inspecciones_actividades
CREATE TABLE IF NOT EXISTS inspecciones_actividades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    actividad_id INT NOT NULL,
    autorizada TINYINT(1) DEFAULT 0,
    autorizado_por_id INT,
    orden_cliente VARCHAR(100),
    servicio_id INT,
    notas TEXT,
    fecha_autorizacion DATETIME NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    updated_by INT,
    deleted_by INT,
    deleted_at TIMESTAMP NULL,
    UNIQUE KEY uk_inspeccion_actividad (inspeccion_id, actividad_id),
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (actividad_id) REFERENCES actividades_estandar(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 38. Table: inspecciones_evidencias
CREATE TABLE IF NOT EXISTS inspecciones_evidencias (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    actividad_id INT,
    ruta_imagen VARCHAR(500) NOT NULL,
    comentario TEXT,
    orden INT DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by INT,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (actividad_id) REFERENCES inspecciones_actividades(id) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 39. Table: tipos_mantenimiento (NUEVO)
CREATE TABLE IF NOT EXISTS tipos_mantenimiento (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed default types
INSERT IGNORE INTO tipos_mantenimiento (nombre) VALUES ('preventivo'), ('correctivo'), ('predictivo');

SET FOREIGN_KEY_CHECKS = 1;

-- 28. Trigger: tg_operaciones_before_delete (Integridad de operaciones)
DELIMITER $$
CREATE TRIGGER tg_operaciones_before_delete
BEFORE DELETE ON operaciones
FOR EACH ROW
BEGIN
    DECLARE v_master_id INT;

    -- 1. Prohibir la eliminación de la operación maestra a nivel de motor de DB
    IF OLD.is_master = 1 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'No se puede eliminar la Operación Maestra (Alistamiento/General).';
    END IF;

    -- 2. Identificar la operación maestra del mismo servicio
    SELECT id INTO v_master_id 
    FROM operaciones 
    WHERE servicio_id = OLD.servicio_id AND is_master = 1 
    LIMIT 1;

    -- 3. Mover recursos a la operación maestra antes de borrar la detallada
    IF v_master_id IS NOT NULL THEN
        UPDATE servicio_staff SET operacion_id = v_master_id WHERE operacion_id = OLD.id;
        UPDATE servicio_repuestos SET operacion_id = v_master_id WHERE operacion_id = OLD.id;
    END IF;
END$$
DELIMITER ;

-- 29. Views: Estadísticas y Reportes
DROP VIEW IF EXISTS `v_department_stats`;
DROP TABLE IF EXISTS `v_department_stats`;
CREATE OR REPLACE VIEW `v_department_stats` AS 
select `d`.`id` AS `id`,`d`.`name` AS `department_name`,count(`s`.`id`) AS `total_employees`,count(case when `s`.`is_active` = 1 then 1 end) AS `active_employees`,count(case when `s`.`is_active` = 0 then 1 end) AS `inactive_employees`,avg(`s`.`salary`) AS `average_salary`,min(`s`.`salary`) AS `min_salary`,max(`s`.`salary`) AS `max_salary` 
from (`departments` `d` left join `staff` `s` on(`d`.`id` = `s`.`department_id` and `s`.`deleted_at` is null)) 
where `d`.`is_active` = 1 group by `d`.`id`,`d`.`name`;

DROP VIEW IF EXISTS `v_servicio_costos_detallados`;
DROP TABLE IF EXISTS `v_servicio_costos_detallados`;
CREATE OR REPLACE VIEW `v_servicio_costos_detallados` AS 
select `s`.`id` AS `servicio_id`,`o`.`id` AS `operacion_id`,`o`.`descripcion` AS `operacion_nombre`,`o`.`is_master` AS `is_master`,`o`.`fecha_inicio` AS `fecha_inicio`,`o`.`fecha_fin` AS `fecha_fin`,coalesce(timestampdiff(SECOND,`o`.`fecha_inicio`,coalesce(`o`.`fecha_fin`,current_timestamp())) / 3600.0,0) AS `horas_duracion`,coalesce(sum(`sr`.`cantidad` * `sr`.`costo_unitario`),0) AS `subtotal_repuestos`,count(distinct `ss`.`staff_id`) AS `total_personal` 
from (((`servicios` `s` join `operaciones` `o` on(`s`.`id` = `o`.`servicio_id`)) left join `servicio_repuestos` `sr` on(`o`.`id` = `sr`.`operacion_id`)) left join `servicio_staff` `ss` on(`o`.`id` = `ss`.`operacion_id`)) 
group by `s`.`id`,`o`.`id`;

DROP VIEW IF EXISTS `v_staff_complete`;
DROP TABLE IF EXISTS `v_staff_complete`;
CREATE OR REPLACE VIEW `v_staff_complete` AS 
select `s`.`id` AS `id`,`s`.`staff_code` AS `staff_code`,`s`.`first_name` AS `first_name`,`s`.`last_name` AS `last_name`,concat(`s`.`first_name`,' ',`s`.`last_name`) AS `full_name`,`s`.`email` AS `email`,`s`.`phone` AS `phone`,`s`.`hire_date` AS `hire_date`,`s`.`birth_date` AS `birth_date`,`s`.`identification_type` AS `identification_type`,`s`.`identification_number` AS `identification_number`,`s`.`photo_url` AS `photo_url`,`s`.`is_active` AS `is_active`,`s`.`salary` AS `salary`,`s`.`address` AS `address`,`s`.`emergency_contact_name` AS `emergency_contact_name`,`s`.`emergency_contact_phone` AS `emergency_contact_phone`,`d`.`name` AS `department_name`,`p`.`title` AS `position_title`,`p`.`min_salary` AS `min_salary`,`p`.`max_salary` AS `max_salary`,`s`.`created_at` AS `created_at`,`s`.`updated_at` AS `updated_at` 
from ((`staff` `s` join `departments` `d` on(`s`.`department_id` = `d`.`id`)) join `positions` `p` on(`s`.`position_id` = `p`.`id`)) 
where `s`.`deleted_at` is null;
