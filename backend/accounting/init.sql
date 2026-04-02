-- =============================================================================
-- MÓDULO: Contabilidad y Facturación (accounting)
-- PROPÓSITO: Inicializar TODAS las tablas del módulo contable-financiero.
-- Este archivo es idempotente. Puede ejecutarse en cualquier DB.
-- =============================================================================

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- -----------------------------------------------------------------------------
-- 1. CONTROL DE SERVICIOS (Snapshot Comercial)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_control_servicios (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    valor_snapshot DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    total_repuestos DECIMAL(18,2) DEFAULT 0.00,
    total_mano_obra DECIMAL(18,2) DEFAULT 0.00,
    total_facturado DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    estado_comercial_cache ENUM('NO_FACTURADO', 'CAUSADO', 'FACTURACION_PARCIAL', 'FACTURADO_TOTAL', 'ANULADO') DEFAULT 'NO_FACTURADO',
    fecha_legalizacion TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (servicio_id) REFERENCES servicios(id),
    UNIQUE KEY idx_unique_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 2. PLAN ÚNICO DE CUENTAS (PUC)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fin_puc (
    id INT AUTO_INCREMENT PRIMARY KEY,
    codigo_cuenta VARCHAR(20) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    naturaleza ENUM('DEBITO', 'CREDITO') NOT NULL,
    tipo_cuenta ENUM('ACTIVO', 'PASIVO', 'PATRIMONIO', 'INGRESO', 'GASTO', 'COSTO', 'ORDEN') NOT NULL,
    nivel INT DEFAULT 1,
    activo TINYINT(1) DEFAULT 1,
    fecha_creacion DATETIME DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_codigo (codigo_cuenta)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Datos inicial PUC
INSERT IGNORE INTO fin_puc (codigo_cuenta, nombre, naturaleza, tipo_cuenta, nivel) VALUES
('1', 'ACTIVO', 'DEBITO', 'ACTIVO', 1),
('11', 'DISPONIBLE', 'DEBITO', 'ACTIVO', 2),
('1105', 'CAJA', 'DEBITO', 'ACTIVO', 3),
('110505', 'CAJA GENERAL', 'DEBITO', 'ACTIVO', 4),
('13', 'DEUDORES', 'DEBITO', 'ACTIVO', 2),
('1305', 'CLIENTES', 'DEBITO', 'ACTIVO', 3),
('130505', 'CLIENTES NACIONALES', 'DEBITO', 'ACTIVO', 4),
('1355', 'ANTICIPO DE IMPUESTOS Y CONTRIBUCIONES', 'DEBITO', 'ACTIVO', 2),
('135515', 'RETENCION EN LA FUENTE', 'DEBITO', 'ACTIVO', 3),
('135517', 'IMPUESTO A LAS VENTAS RETENIDO (RETEIVA)', 'DEBITO', 'ACTIVO', 3),
('135518', 'IMPUESTO DE INDUSTRIA Y COMERCIO RETENIDO (RETEICA)', 'DEBITO', 'ACTIVO', 3),
('2', 'PASIVO', 'CREDITO', 'PASIVO', 1),
('24', 'IMPUESTOS, GRAVAMENES Y TASAS', 'CREDITO', 'PASIVO', 2),
('2408', 'IMPUESTO SOBRE LAS VENTAS POR PAGAR (IVA)', 'CREDITO', 'PASIVO', 3),
('4', 'INGRESOS', 'CREDITO', 'INGRESO', 1),
('41', 'OPERACIONALES', 'CREDITO', 'INGRESO', 2),
('4120', 'CONSTRUCCION (SERVICIOS TECNICOS)', 'CREDITO', 'INGRESO', 3),
('4135', 'COMERCIO AL POR MAYOR Y AL POR MENOR', 'CREDITO', 'INGRESO', 3),
('412005', 'MANTENIMIENTO Y REPARACION', 'CREDITO', 'INGRESO', 4);

-- -----------------------------------------------------------------------------
-- 3. PERIODOS CONTABLES
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fin_periodos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    fecha_inicio DATE NULL,
    fecha_fin DATE NULL,
    estado ENUM('ABIERTO', 'CERRADO') DEFAULT 'ABIERTO',
    fecha_cierre DATETIME NULL,
    usuario_cierre_id INT NULL,
    usuario_apertura_id INT NULL,
    fecha_apertura DATETIME NULL,
    UNIQUE KEY uk_periodo (anio, mes),
    INDEX idx_anio_mes (anio, mes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Periodos iniciales
INSERT IGNORE INTO fin_periodos (anio, mes, estado) VALUES
(2025, 11, 'CERRADO'),
(2025, 12, 'CERRADO'),
(2026, 1, 'ABIERTO'),
(2026, 2, 'ABIERTO'),
(2026, 3, 'ABIERTO'),
(2026, 4, 'ABIERTO'),
(2026, 5, 'ABIERTO'),
(2026, 6, 'ABIERTO');

-- -----------------------------------------------------------------------------
-- 4. CONFIGURACIÓN DE CAUSACIÓN (Reglas de Negocio)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fin_config_causacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evento_codigo VARCHAR(50) NOT NULL,
    puc_cuenta_id INT NOT NULL,
    tipo_movimiento ENUM('DEBITO', 'CREDITO') NOT NULL,
    base_calculo ENUM('TOTAL', 'SUBTOTAL', 'IMPUESTO', 'REPUESTOS', 'MANO_OBRA') DEFAULT 'TOTAL',
    porcentaje DECIMAL(5,2) DEFAULT 100.00,
    descripcion VARCHAR(255),
    activo TINYINT(1) DEFAULT 1,
    FOREIGN KEY (puc_cuenta_id) REFERENCES fin_puc(id),
    INDEX idx_evento (evento_codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Reglas de causación por defecto
INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion)
SELECT 'GENERAR_FACTURA', id, 'DEBITO', 'TOTAL', 100.00, 'CxC Cliente' FROM fin_puc WHERE codigo_cuenta = '130505';

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion)
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'REPUESTOS', 100.00, 'Venta de Repuestos' FROM fin_puc WHERE codigo_cuenta = '4135';

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion)
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'MANO_OBRA', 100.00, 'Ingreso Servicios Técnicos (M.O.)' FROM fin_puc WHERE codigo_cuenta = '412005';

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion)
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'IMPUESTO', 100.00, 'IVA por Pagar' FROM fin_puc WHERE codigo_cuenta = '2408';

-- -----------------------------------------------------------------------------
-- 5. FACTURAS (Cabecera)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_facturas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    prefijo VARCHAR(10) NOT NULL,
    numero_factura VARCHAR(20) NOT NULL,
    cufe VARCHAR(255),
    qr_url TEXT,
    metodo_pago ENUM('CONTADO', 'CREDITO') DEFAULT 'CONTADO',
    fecha_emision DATE NOT NULL,
    fecha_vencimiento DATE,
    pdf_url TEXT,
    subtotal DECIMAL(18,2) NOT NULL DEFAULT 0,
    iva DECIMAL(18,2) NOT NULL DEFAULT 0,
    total_neto DECIMAL(18,2) NOT NULL DEFAULT 0,
    saldo_actual DECIMAL(18,2) NOT NULL DEFAULT 0,
    estado ENUM('ACTIVA', 'ANULADA', 'PAGADA') DEFAULT 'ACTIVA',
    creado_por INT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id),
    INDEX idx_doc (prefijo, numero_factura)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 6. DETALLE DE FACTURA (Ítems/Servicios)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_factura_items (
    id INT AUTO_INCREMENT PRIMARY KEY,
    factura_id INT NOT NULL,
    servicio_id INT NOT NULL,
    monto_repuestos DECIMAL(18,2) DEFAULT 0,
    monto_mano_obra DECIMAL(18,2) DEFAULT 0,
    base_iva DECIMAL(18,2) DEFAULT 0,
    valor_iva DECIMAL(18,2) DEFAULT 0,
    subtotal_item DECIMAL(18,2) DEFAULT 0,
    FOREIGN KEY (factura_id) REFERENCES fac_facturas(id),
    FOREIGN KEY (servicio_id) REFERENCES servicios(id),
    INDEX idx_factura (factura_id),
    INDEX idx_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 7. PAGOS Y CARTERA
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_pagos_cartera (
    id INT AUTO_INCREMENT PRIMARY KEY,
    factura_id INT NOT NULL,
    monto_pago DECIMAL(18,2) NOT NULL,
    fecha_pago DATETIME NOT NULL,
    referencia_pago VARCHAR(100),
    creado_por INT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (factura_id) REFERENCES fac_facturas(id),
    INDEX idx_factura_pago (factura_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 8. LIBROS CONTABLES (Asientos)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fin_asientos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    referencia VARCHAR(50) NOT NULL,
    fecha DATE NOT NULL,
    evento_codigo VARCHAR(50),
    total_debito DECIMAL(18,2) DEFAULT 0,
    total_credito DECIMAL(18,2) DEFAULT 0,
    creado_por INT,
    fecha_registro TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_ref (referencia)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS fin_asientos_detalle (
    id INT AUTO_INCREMENT PRIMARY KEY,
    asiento_id INT NOT NULL,
    puc_cuenta_id INT NOT NULL,
    tipo_movimiento ENUM('DEBITO', 'CREDITO') NOT NULL,
    valor DECIMAL(18,2) NOT NULL,
    descripcion VARCHAR(255),
    FOREIGN KEY (asiento_id) REFERENCES fin_asientos(id),
    FOREIGN KEY (puc_cuenta_id) REFERENCES fin_puc(id),
    INDEX idx_asiento (asiento_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- Log de asientos
CREATE TABLE IF NOT EXISTS fin_asientos_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    asiento_id INT,
    accion VARCHAR(50),
    descripcion TEXT,
    usuario_id INT,
    fecha DATETIME DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 9. AUDITORÍAS FINANCIERAS (SoD)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_auditorias_servicio (
    id            INT NOT NULL AUTO_INCREMENT,
    servicio_id   INT NOT NULL,
    auditor_id    INT NOT NULL,
    fecha_auditoria DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    comentario    TEXT NULL,
    ciclo         INT NOT NULL DEFAULT 1,
    es_excepcion  TINYINT(1) NOT NULL DEFAULT 0 COMMENT '1 si fue aprobada ignorando alertas de IA',
    created_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_servicio (servicio_id),
    INDEX idx_auditor (auditor_id),
    CONSTRAINT fk_auditoria_servicio FOREIGN KEY (servicio_id) REFERENCES fac_control_servicios(id) ON DELETE CASCADE,
    CONSTRAINT fk_auditoria_auditor FOREIGN KEY (auditor_id) REFERENCES usuarios(id) ON DELETE RESTRICT
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 9.5. LOGS DE AUDITORÍA IA (Persistencia)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_auditoria_ia_logs (
    id            INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id   INT NOT NULL,
    ciclo         INT NOT NULL DEFAULT 1,
    analisis_text TEXT NOT NULL,
    fuente        VARCHAR(255) NULL,
    created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_servicio_ciclo (servicio_id, ciclo),
    CONSTRAINT fk_ia_logs_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fac_audit_ciclos (
    id           INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id  INT NOT NULL,
    ciclo_actual INT NOT NULL DEFAULT 1,
    updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_servicio (servicio_id),
    CONSTRAINT fk_ciclo_servicio_v22 FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -----------------------------------------------------------------------------
-- 10. AJUSTES MANUALES A SNAPSHOTS
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_snapshot_ajustes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    servicio_id INT NOT NULL,
    usuario_id INT NOT NULL,
    campo ENUM('MANO_OBRA', 'REPUESTOS') NOT NULL,
    valor_anterior DECIMAL(15,2) NOT NULL,
    valor_nuevo DECIMAL(15,2) NOT NULL,
    motivo TEXT NOT NULL,
    fecha DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ajuste_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
    CONSTRAINT fk_ajuste_usuario FOREIGN KEY (usuario_id) REFERENCES usuarios(id),
    INDEX idx_ajuste_servicio (servicio_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- -----------------------------------------------------------------------------
-- 11. CONFIGURACIÓN DE CONSECUTIVOS (Factus)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fac_config_consecutivos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    prefijo VARCHAR(50) NOT NULL,
    valor_actual INT NOT NULL DEFAULT 1,
    descripcion VARCHAR(255),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO fac_config_consecutivos (prefijo, valor_actual, descripcion)
VALUES ('INV/2026/', 1, 'Consecutivo para Factus Reference Code');

-- -----------------------------------------------------------------------------
-- 12. CONFIGURACIÓN FISCAL (Factus/DIAN)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cnf_responsabilidades_fiscales (
    codigo VARCHAR(10) NOT NULL PRIMARY KEY,
    descripcion VARCHAR(150) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT IGNORE INTO cnf_responsabilidades_fiscales (codigo, descripcion) VALUES
('O-13', 'Gran Contribuyente'),
('O-15', 'Autorretenedor'),
('O-23', 'Agente de retención del Impuesto sobre las ventas'),
('O-47', 'Régimen de tributación simple'),
('R-99-PN', 'No responsable');

CREATE TABLE IF NOT EXISTS cnf_tarifas_ica (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ciudad_id INT NOT NULL,
    tarifa_x_mil DECIMAL(10,4) NOT NULL,
    base_minima_uvt DECIMAL(15,2) DEFAULT 0.00,
    FOREIGN KEY (ciudad_id) REFERENCES ciudades(id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 13. ESTADOS CONTABLES EN WORKFLOW
-- =============================================================================
INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES
('LEGALIZADO', 'Legalizado', 'Servicio con snapshot de valores listo para facturar', 0, 0, 6)
ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), orden=6;

-- Solo insertar el estado de proceso si no existe ya uno mapeado al código base LEGALIZADO
INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden, bloquea_cierre)
SELECT 'Legalizado', '#009688', 'servicio', 'LEGALIZADO', 55, 0
FROM (SELECT 1) AS tmp
WHERE NOT EXISTS (
    SELECT 1 FROM estados_proceso 
    WHERE modulo = 'servicio' AND estado_base_codigo = 'LEGALIZADO'
);

SET FOREIGN_KEY_CHECKS = 1;

SELECT 'Módulo de Contabilidad y Facturación inicializado' AS Resultado;
