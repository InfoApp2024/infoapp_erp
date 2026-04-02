-- Tabla principal de Inspecciones
CREATE TABLE IF NOT EXISTS inspecciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    o_inspe VARCHAR(20) UNIQUE, -- Identificador generado por trigger (ej: INS-202310-001)
    estado_id INT NOT NULL,
    sitio VARCHAR(100),
    fecha_inspe DATE,
    equipo_id INT NOT NULL,
    observacion TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (estado_id) REFERENCES estados(id),
    FOREIGN KEY (equipo_id) REFERENCES equipos(id),
    FOREIGN KEY (created_by) REFERENCES usuarios(id),
    FOREIGN KEY (updated_by) REFERENCES usuarios(id)
);

-- Tabla intermedia para Inspecciones <-> Inspectores
CREATE TABLE IF NOT EXISTS inspecciones_inspectores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    usuario_id INT NOT NULL, -- ID del inspector (usuario)
    rol_inspector VARCHAR(50) DEFAULT 'Principal', -- 'Principal', 'Asistente', etc.
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_inspector (inspeccion_id, usuario_id)
);

-- Trigger para generar o_inspe automáticamente
-- Formato: INS-YYYYMM-XXXX (ej: INS-202310-0001)
DELIMITER //
CREATE TRIGGER before_insert_inspecciones
BEFORE INSERT ON inspecciones
FOR EACH ROW
BEGIN
    DECLARE next_id INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(NEW.fecha_inspe, '%Y%m');
    
    -- Obtener el siguiente correlativo para ese mes
    SELECT COUNT(*) + 1 INTO next_id 
    FROM inspecciones 
    WHERE DATE_FORMAT(fecha_inspe, '%Y%m') = year_month;
    
    SET NEW.o_inspe = CONCAT('INS-', year_month, '-', LPAD(next_id, 4, '0'));
END//
DELIMITER ;
