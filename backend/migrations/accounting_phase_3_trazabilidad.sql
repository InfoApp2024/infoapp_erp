

-- 1. Agregar columna servicio_id para vincular con la orden de trabajo (Trazabilidad)
ALTER TABLE fac_facturas 
ADD COLUMN servicio_id INT NULL AFTER cliente_id;

-- 2. Agregar columnas para cumplimiento de facturación electrónica (DIAN)
ALTER TABLE fac_facturas 
ADD COLUMN qr_url TEXT NULL AFTER cufe,
ADD COLUMN xml_url TEXT NULL AFTER qr_url;

-- 3. Crear Llave Foránea para asegurar integridad
ALTER TABLE fac_facturas
ADD CONSTRAINT fk_factura_servicio
FOREIGN KEY (servicio_id) REFERENCES servicios(id);

-- 4. Índice para búsquedas rápidas por servicio
CREATE INDEX idx_factura_servicio ON fac_facturas(servicio_id);
