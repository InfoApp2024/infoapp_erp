

-- Insertar o actualizar periodo de Febrero 2026
INSERT INTO fin_periodos (anio, mes, estado) 
VALUES (2026, 2, 'ABIERTO')
ON DUPLICATE KEY UPDATE estado = 'ABIERTO';
