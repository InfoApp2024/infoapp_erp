

ALTER TABLE fac_facturas ADD COLUMN observaciones TEXT AFTER cufe;

-- Registrar el cambio en el log de auditoría si existe
-- INSERT INTO logs_sistema (evento, descripcion) VALUES ('MIGRACION', 'Añadida columna observaciones a fac_facturas');
