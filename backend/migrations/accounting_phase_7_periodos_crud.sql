

-- 1. Agregar columnas de fechas y auditoría faltantes a fin_periodos
ALTER TABLE fin_periodos 
ADD COLUMN fecha_inicio DATE NULL AFTER mes,
ADD COLUMN fecha_fin DATE NULL AFTER fecha_inicio,
ADD COLUMN usuario_apertura_id INT NULL AFTER estado,
ADD COLUMN fecha_apertura DATETIME NULL AFTER usuario_apertura_id;

-- 2. Índices para optimización
CREATE INDEX idx_periodo_fechas ON fin_periodos(fecha_inicio, fecha_fin);

-- 3. Llaves foráneas para auditoría
ALTER TABLE fin_periodos
ADD CONSTRAINT fk_periodo_usuario_apertura FOREIGN KEY (usuario_apertura_id) REFERENCES usuarios(id),
ADD CONSTRAINT fk_periodo_usuario_cierre FOREIGN KEY (usuario_cierre_id) REFERENCES usuarios(id);

-- 4. Poblar fechas para periodos existentes (Aproximación mensual)
UPDATE fin_periodos 
SET fecha_inicio = STR_TO_DATE(CONCAT(anio, '-', mes, '-01'), '%Y-%m-%d'),
    fecha_fin = LAST_DAY(STR_TO_DATE(CONCAT(anio, '-', mes, '-01'), '%Y-%m-%d'))
WHERE fecha_inicio IS NULL;
