

ALTER TABLE fac_facturas
ADD COLUMN raw_response_json LONGTEXT NULL COMMENT 'Respuesta JSON completa de Factus para auditoría' AFTER pdf_url;

-- Nota: LONGTEXT asegura espacio suficiente para respuestas con múltiples errores o QR en base64.
