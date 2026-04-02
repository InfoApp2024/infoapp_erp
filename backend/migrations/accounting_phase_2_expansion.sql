-- accounting_phase_2_expansion.sql
-- Ampliación para Mano de Obra (M.O.)
-- Autor: Senior Developer / Architect

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- 1. Ampliar fac_control_servicios
ALTER TABLE fac_control_servicios 
ADD COLUMN total_repuestos DECIMAL(18,2) DEFAULT 0.00 AFTER valor_snapshot,
ADD COLUMN total_mano_obra DECIMAL(18,2) DEFAULT 0.00 AFTER total_repuestos;

-- 2. Expandir el PUC (Cuentas de Ingreso)
INSERT IGNORE INTO fin_puc (codigo_cuenta, nombre, naturaleza, tipo_cuenta, nivel) VALUES 
('4120', 'CONSTRUCCION (SERVICIOS TECNICOS)', 'CREDITO', 'INGRESO', 3),
('412005', 'MANTENIMIENTO Y REPARACION', 'CREDITO', 'INGRESO', 4);

-- 3. Refactorizar la Matriz de Causación para segmentar ingresos
-- Primero eliminamos la regla genérica de 4135 de la fase anterior para GENERAR_FACTURA
DELETE FROM fin_config_causacion 
WHERE evento_codigo = 'GENERAR_FACTURA' AND puc_cuenta_id IN (SELECT id FROM fin_puc WHERE codigo_cuenta = '4135');

-- Nueva Regla: Ingreso por Repuestos (100% de la base REPUESTOS)
INSERT INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion) 
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'REPUESTOS', 100.00, 'Venta de Repuestos' 
FROM fin_puc WHERE codigo_cuenta = '4135';

-- Nueva Regla: Ingreso por Mano de Obra (100% de la base MANO_OBRA)
INSERT INTO fin_config_causacion (evento_codigo, puc_cuenta_id, tipo_movimiento, base_calculo, porcentaje, descripcion) 
SELECT 'GENERAR_FACTURA', id, 'CREDITO', 'MANO_OBRA', 100.00, 'Ingreso Servicios Técnicos (M.O.)' 
FROM fin_puc WHERE codigo_cuenta = '412005';

SET FOREIGN_KEY_CHECKS = 1;
