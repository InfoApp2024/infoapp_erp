-- fix_estado_comercial.sql
-- Agregar estado CAUSADO a la columna cache de fac_control_servicios
-- Autor: Senior Developer / Architect

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

ALTER TABLE fac_control_servicios 
MODIFY COLUMN estado_comercial_cache ENUM('PENDIENTE', 'CAUSADO', 'FACTURADO', 'ANULADO') DEFAULT 'PENDIENTE';

SET FOREIGN_KEY_CHECKS = 1;
