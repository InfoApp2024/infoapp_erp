-- SQL Migration to add 'id_especialidad' to 'staff' table

-- 1. Add the column
ALTER TABLE staff ADD COLUMN id_especialidad INT NULL AFTER position_id;

-- 2. Add Foreign Key constraint (assuming 'especialidades' table exists and has 'id' column)
ALTER TABLE staff ADD CONSTRAINT fk_staff_especialidad 
FOREIGN KEY (id_especialidad) REFERENCES especialidades(id) 
ON DELETE SET NULL;
