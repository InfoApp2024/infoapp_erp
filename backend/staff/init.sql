-- =============================================================================
-- MÓDULO: Staff / RRHH - Auditoría
-- PROPÓSITO: Registro de auditoría de cambios en personal.
-- Usada por los triggers: staff_after_insert, staff_after_update
-- =============================================================================

SET NAMES utf8mb4;

-- 1. Tabla de log de auditoría de Staff
CREATE TABLE IF NOT EXISTS staff_audit_log (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    staff_id BIGINT UNSIGNED NOT NULL,
    action ENUM('created', 'updated', 'deactivated', 'reactivated') NOT NULL,
    changed_by INT NULL COMMENT 'ID del usuario que realizó el cambio',
    changed_fields JSON NULL COMMENT 'Campos modificados en formato JSON',
    old_values JSON NULL COMMENT 'Valores anteriores',
    new_values JSON NULL COMMENT 'Valores nuevos',
    ip_address VARCHAR(45) NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (id),
    INDEX idx_staff (staff_id),
    INDEX idx_action (action),
    INDEX idx_created (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Triggers de auditoría de Staff
-- Usamos DELIMITER para que el motor de DB procese el bloque completo

DELIMITER $$

CREATE TRIGGER staff_after_insert 
AFTER INSERT ON staff
FOR EACH ROW
BEGIN
    INSERT INTO staff_audit_log (staff_id, action, new_values, changed_by)
    VALUES (
        NEW.id, 
        'created',
        JSON_OBJECT(
            'staff_code', NEW.staff_code,
            'first_name', NEW.first_name,
            'last_name', NEW.last_name,
            'email', NEW.email,
            'department_id', NEW.department_id,
            'position_id', NEW.position_id,
            'is_active', NEW.is_active
        ),
        'system'
    );
END$$

CREATE TRIGGER staff_after_update 
AFTER UPDATE ON staff
FOR EACH ROW
BEGIN
    DECLARE changed_fields JSON;
    DECLARE old_values JSON;
    DECLARE new_values JSON;
    DECLARE action_type VARCHAR(20) DEFAULT 'updated';
    
    -- Detectar tipo de acción
    IF OLD.is_active = TRUE AND NEW.is_active = FALSE THEN
        SET action_type = 'deactivated';
    ELSEIF OLD.is_active = FALSE AND NEW.is_active = TRUE THEN
        SET action_type = 'reactivated';
    END IF;
    
    -- Construir JSON con cambios
    SET changed_fields = JSON_ARRAY();
    SET old_values = JSON_OBJECT();
    SET new_values = JSON_OBJECT();
    
    IF OLD.first_name != NEW.first_name THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'first_name');
        SET old_values = JSON_SET(old_values, '$.first_name', OLD.first_name);
        SET new_values = JSON_SET(new_values, '$.first_name', NEW.first_name);
    END IF;
    
    IF OLD.last_name != NEW.last_name THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'last_name');
        SET old_values = JSON_SET(old_values, '$.last_name', OLD.last_name);
        SET new_values = JSON_SET(new_values, '$.last_name', NEW.last_name);
    END IF;
    
    IF OLD.email != NEW.email THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'email');
        SET old_values = JSON_SET(old_values, '$.email', OLD.email);
        SET new_values = JSON_SET(new_values, '$.email', NEW.email);
    END IF;
    
    IF OLD.department_id != NEW.department_id THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'department_id');
        SET old_values = JSON_SET(old_values, '$.department_id', OLD.department_id);
        SET new_values = JSON_SET(new_values, '$.department_id', NEW.department_id);
    END IF;
    
    IF OLD.position_id != NEW.position_id THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'position_id');
        SET old_values = JSON_SET(old_values, '$.position_id', OLD.position_id);
        SET new_values = JSON_SET(new_values, '$.position_id', NEW.position_id);
    END IF;
    
    IF OLD.is_active != NEW.is_active THEN
        SET changed_fields = JSON_ARRAY_APPEND(changed_fields, '$', 'is_active');
        SET old_values = JSON_SET(old_values, '$.is_active', OLD.is_active);
        SET new_values = JSON_SET(new_values, '$.is_active', NEW.is_active);
    END IF;
    
    -- Insertar log solo si hay cambios
    IF JSON_LENGTH(changed_fields) > 0 THEN
        INSERT INTO staff_audit_log (staff_id, action, changed_fields, old_values, new_values, changed_by)
        VALUES (NEW.id, action_type, changed_fields, old_values, new_values, 'system');
    END IF;
END$$

DELIMITER ;
