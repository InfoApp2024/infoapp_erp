

-- 1. Asegurar que la columna 'description' exista (En la captura se ve ausente)
-- Usamos un procedimiento para evitar errores si ya existe
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS AddDescriptionColumn()
BEGIN
    IF NOT EXISTS (
        SELECT * FROM information_schema.COLUMNS 
        WHERE TABLE_SCHEMA = 'infoapp_db' 
        AND TABLE_NAME = 'app_settings' 
        AND COLUMN_NAME = 'description'
    ) THEN
        ALTER TABLE app_settings ADD COLUMN description VARCHAR(255) AFTER setting_value;
    END IF;
END //
DELIMITER ;

CALL AddDescriptionColumn();
DROP PROCEDURE AddDescriptionColumn;

-- 2. Asegurar que 'setting_key' tenga longitud suficiente (Captura muestra 50, se recomienda 100)
ALTER TABLE app_settings MODIFY COLUMN setting_key VARCHAR(100) NOT NULL;

-- 3. Inicializar / Actualizar llaves para Factus (Valores de Sandbox)
INSERT INTO app_settings (setting_key, setting_value, description) VALUES
('factus_client_id', '', 'Factus OAuth2 Client ID'),
('factus_client_secret', '', 'Factus OAuth2 Client Secret'),
('factus_username', '', 'Factus Username'),
('factus_password', '', 'Factus Password'),
('factus_numbering_range_id', '', 'Factus Active Numbering Range ID')
ON DUPLICATE KEY UPDATE 
    description = VALUES(description),
    updated_at = CURRENT_TIMESTAMP;
