

-- 1. Añadir columna ver_detalle_cotizacion a fac_control_servicios
ALTER TABLE fac_control_servicios 
ADD COLUMN ver_detalle_cotizacion TINYINT(1) DEFAULT 1 COMMENT '0: Resumen Consolidado, 1: Detalle Desglosado' AFTER estado_comercial_cache;

-- 2. Índice opcional para reportes (si fuera necesario filtrar por este criterio)
CREATE INDEX idx_fcs_quote_visibility ON fac_control_servicios(ver_detalle_cotizacion);
