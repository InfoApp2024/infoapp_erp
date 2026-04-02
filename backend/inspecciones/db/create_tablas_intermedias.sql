-- Tabla intermedia para Inspecciones <-> Sistemas
CREATE TABLE IF NOT EXISTS inspecciones_sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    sistema_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (sistema_id) REFERENCES sistemas(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_sistema (inspeccion_id, sistema_id)
);

-- Tabla intermedia para Inspecciones <-> Actividades Estándar
CREATE TABLE IF NOT EXISTS inspecciones_actividades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    actividad_id INT NOT NULL,
    estado ENUM('Pendiente', 'En Proceso', 'Completada', 'Omitida') DEFAULT 'Pendiente',
    observaciones TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (actividad_id) REFERENCES actividades_estandar(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_actividad (inspeccion_id, actividad_id)
);
