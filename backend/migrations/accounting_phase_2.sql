-- accounting_phase_2.sql
-- Fase 2: Fundaciones Contables (PUC, Periodos y Matriz de Causación)
-- Autor: Senior Developer / Architect

-- 1. Tabla: Plan Único de Cuentas (PUC)
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

-- 2. Tabla: Gestión de Periodos Contables
CREATE TABLE IF NOT EXISTS fin_periodos (
    id INT AUTO_INCREMENT PRIMARY KEY,
    anio INT NOT NULL,
    mes INT NOT NULL,
    estado ENUM('ABIERTO', 'CERRADO') DEFAULT 'ABIERTO',
    fecha_cierre DATETIME NULL,
    usuario_cierre_id INT NULL,
    UNIQUE KEY uk_periodo (anio, mes),
    INDEX idx_anio_mes (anio, mes)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 3. Tabla: Matriz de Configuración de Causación (Reglas de Negocio)
CREATE TABLE IF NOT EXISTS fin_config_causacion (
    id INT AUTO_INCREMENT PRIMARY KEY,
    evento_codigo VARCHAR(50) NOT NULL, -- Ej: GENERAR_FACTURA, PAGO_CLIENTE
    puc_cuenta_id INT NOT NULL,
    tipo_movimiento ENUM('DEBITO', 'CREDITO') NOT NULL,
    base_calculo ENUM('TOTAL', 'SUBTOTAL', 'IMPUESTO') DEFAULT 'TOTAL',
    porcentaje DECIMAL(5,2) DEFAULT 100.00,
    descripcion VARCHAR(255),
    activo TINYINT(1) DEFAULT 1,
    FOREIGN KEY (puc_cuenta_id) REFERENCES fin_puc(id),
    INDEX idx_evento (evento_codigo)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 4. Datos Iniciales (Ejemplos Estándar)
INSERT IGNORE INTO fin_puc (codigo_cuenta, nombre, naturaleza, tipo_cuenta, nivel) VALUES 
('1', 'ACTIVO', 'DEBITO', 'ACTIVO', 1),
('11', 'DISPONIBLE', 'DEBITO', 'ACTIVO', 2),
('1105', 'CAJA', 'DEBITO', 'ACTIVO', 3),
('110505', 'CAJA GENERAL', 'DEBITO', 'ACTIVO', 4),
('13', 'DEUDORES', 'DEBITO', 'ACTIVO', 2),
('1305', 'CLIENTES', 'DEBITO', 'ACTIVO', 3),
('130505', 'CLIENTES NACIONALES', 'DEBITO', 'ACTIVO', 4),
('2', 'PASIVO', 'CREDITO', 'PASIVO', 1),
('24', 'IMPUESTOS, GRAVAMENES Y TASAS', 'CREDITO', 'PASIVO', 2),
('2408', 'IMPUESTO SOBRE LAS VENTAS POR PAGAR (IVA)', 'CREDITO', 'PASIVO', 3),
('4', 'INGRESOS', 'CREDITO', 'INGRESO', 1),
('41', 'OPERACIONALES', 'CREDITO', 'INGRESO', 2),
('4135', 'COMERCIO AL POR MAYOR Y AL POR MENOR', 'CREDITO', 'INGRESO', 3);

-- 5. Configuración de Causación para Facturación (Ejemplo)
-- Al GENERAR_FACTURA:
-- 100% del TOTAL va al Débito de Clientes (130505)
-- 100% del SUBTOTAL va al Crédito de Ingresos (4135)
-- 100% del IMPUESTO va al Crédito de IVA (2408)

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion) 
SELECT 'GENERAR_FACTURA', id, 'DEBITO', 'TOTAL', 100.00, 'CxC Cliente' FROM fin_puc WHERE codigo_cuenta = '130505';

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion) 
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'SUBTOTAL', 100.00, 'Ingreso Operacional' FROM fin_puc WHERE codigo_cuenta = '4135';

INSERT IGNORE INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion) 
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'IMPUESTO', 100.00, 'IVA por Pagar' FROM fin_puc WHERE codigo_cuenta = '2408';

-- 6. Abrir periodos iniciales
INSERT IGNORE INTO fin_periodos (anio, mes, estado) VALUES 
(2026, 1, 'ABIERTO'),
(2026, 2, 'ABIERTO'),
(2026, 3, 'ABIERTO');
