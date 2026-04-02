

DELIMITER //
CREATE PROCEDURE IF NOT EXISTS FixClientesFields()
BEGIN
    -- 1. Añadir 'dv' si no existe
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'clientes' AND column_name = 'dv') THEN
        ALTER TABLE clientes ADD COLUMN dv VARCHAR(1) DEFAULT NULL AFTER documento_nit;
    END IF;

    -- 2. Añadir 'email_facturacion' si no existe
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'clientes' AND column_name = 'email_facturacion') THEN
        ALTER TABLE clientes ADD COLUMN email_facturacion VARCHAR(150) DEFAULT NULL AFTER email;
    END IF;

    -- 3. Añadir 'responsabilidad_fiscal_id' si no existe
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'clientes' AND column_name = 'responsabilidad_fiscal_id') THEN
        ALTER TABLE clientes ADD COLUMN responsabilidad_fiscal_id VARCHAR(10) DEFAULT 'R-99-PN' AFTER email_facturacion;
    END IF;

    -- 4. Añadir 'es_autorretenedor' si no existe
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'clientes' AND column_name = 'es_autorretenedor') THEN
        ALTER TABLE clientes ADD COLUMN es_autorretenedor TINYINT(1) DEFAULT 0 AFTER responsabilidad_fiscal_id;
    END IF;

    -- 5. Añadir 'es_gran_contribuyente' si no existe
    IF NOT EXISTS (SELECT * FROM information_schema.columns WHERE table_schema = DATABASE() AND table_name = 'clientes' AND column_name = 'es_gran_contribuyente') THEN
        ALTER TABLE clientes ADD COLUMN es_gran_contribuyente TINYINT(1) DEFAULT 0 AFTER es_autorretenedor;
    END IF;
    
    -- 6. Asegurar tipos de datos correctos
    ALTER TABLE clientes
    MODIFY COLUMN dv VARCHAR(1) DEFAULT NULL,
    MODIFY COLUMN email_facturacion VARCHAR(150) DEFAULT NULL,
    MODIFY COLUMN responsabilidad_fiscal_id VARCHAR(10) DEFAULT 'R-99-PN',
    MODIFY COLUMN es_autorretenedor TINYINT(1) DEFAULT 0,
    MODIFY COLUMN es_gran_contribuyente TINYINT(1) DEFAULT 0;
END //
DELIMITER ;
CALL FixClientesFields();
DROP PROCEDURE IF EXISTS FixClientesFields;
