
-- Tabla de Especialidades (Maestra)
CREATE TABLE IF NOT EXISTS especialidades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom_especi VARCHAR(100) NOT NULL,
    valor_hr DECIMAL(10, 2) DEFAULT 0.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Tabla de Tarifas por Cliente (Perfiles)
CREATE TABLE IF NOT EXISTS cliente_perfiles (
    id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    especialidad_id INT NOT NULL,
    valor DECIMAL(10, 2) NOT NULL,
    FOREIGN KEY (cliente_id) REFERENCES clientes(id) ON DELETE CASCADE,
    FOREIGN KEY (especialidad_id) REFERENCES especialidades(id) ON DELETE CASCADE
);

-- Actualización de la tabla clientes (Renombrar valor_mo a perfil)
-- NOTA: Ejecutar manualmente si ya existe la tabla
-- ALTER TABLE clientes CHANGE valor_mo perfil VARCHAR(100);
-- O si se prefiere mantener valor_mo como legacy y agregar perfil:
-- ALTER TABLE clientes ADD COLUMN perfil VARCHAR(100) AFTER limite_credito;
