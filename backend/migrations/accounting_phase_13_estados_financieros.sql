-- Migración Fase 13: Máquina de Estados Financieros

SET NAMES utf8mb4;

-- 1. Agregar las nuevas columnas a servicios
ALTER TABLE servicios 
ADD COLUMN IF NOT EXISTS estado_financiero_id INT DEFAULT NULL,
ADD COLUMN IF NOT EXISTS estado_fin_fecha_inicio DATETIME DEFAULT CURRENT_TIMESTAMP;

-- No agregamos FK estricta aún si falla por datos existentes, pero es buena práctica:
-- ALTER TABLE servicios ADD CONSTRAINT fk_servicio_est_fin FOREIGN KEY (estado_financiero_id) REFERENCES estados_proceso(id);

-- 2. Insertar Estados Base Financieros (Semillas inmutables)
INSERT IGNORE INTO estados_base (codigo, nombre, descripcion, es_final, orden) VALUES
('FIN_PENDIENTE', 'Pendiente Gestión', 'Servicio legalizado, a la espera de gestión contable inicial.', 0, 1),
('FIN_COTIZACION', 'Cotización Enviada', 'Propuesta económica enviada al cliente.', 0, 2),
('FIN_CAUSADO', 'Causado', 'Costo contable reconocido (Accrual).', 0, 3),
('FIN_FACTURADO', 'Facturado', 'Factura electrónica emitida válidamente.', 0, 4),
('FIN_ANULADO', 'Factura Anulada', 'Factura anulada en la DIAN. Requiere refacturación o corrección.', 0, 5),
('FIN_PAGO_PARCIAL', 'Pago Parcial', 'Se ha recibido un abono parcial sobre la cuenta por cobrar.', 0, 6),
('FIN_PAGO_TOTAL', 'Pago Total', 'El pago ha sido recaudado en su totalidad.', 1, 7);

-- 3. Crear los Estados de Proceso en el Módulo FINANCIERO
-- Guardamos variables para usar los IDs luego en las transiciones
INSERT IGNORE INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, orden) VALUES
('Pendiente Gestión', '#9E9E9E', 'FINANCIERO', 'FIN_PENDIENTE', 1),
('Cotización Enviada', '#607D8B', 'FINANCIERO', 'FIN_COTIZACION', 2),
('Causado', '#9C27B0', 'FINANCIERO', 'FIN_CAUSADO', 3),
('Facturado', '#03A9F4', 'FINANCIERO', 'FIN_FACTURADO', 4),
('Factura Anulada', '#F44336', 'FINANCIERO', 'FIN_ANULADO', 5),
('Pago Parcial', '#FF9800', 'FINANCIERO', 'FIN_PAGO_PARCIAL', 6),
('Pago Total', '#4CAF50', 'FINANCIERO', 'FIN_PAGO_TOTAL', 7);
