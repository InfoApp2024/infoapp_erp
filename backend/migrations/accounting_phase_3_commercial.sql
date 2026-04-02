-- accounting_phase_3_commercial_v2.sql
-- Fase 3: Capa Comercial (Facturación y Cartera) + Fundaciones Contables Finales

-- 1. Cabecera de Factura
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

-- 2. Detalle de Factura (Vínculo multiservicio N:N)
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

-- 3. Registro de Pagos (Cartera)
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

-- 4. Libros Contables Oficiales (Fase 3/4 integration)
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

-- 5. Alineación final de estados
ALTER TABLE fac_control_servicios 
MODIFY COLUMN estado_comercial_cache ENUM('NO_FACTURADO', 'CAUSADO', 'FACTURACION_PARCIAL', 'FACTURADO_TOTAL', 'ANULADO') 
DEFAULT 'NO_FACTURADO';
