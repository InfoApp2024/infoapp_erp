-- Insertar los 7 estados base del sistema
INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES
('ABIERTO', 'Abierto', 'Servicio registrado, pendiente de programación o asignación', 0, 1, 1),
('PROGRAMADO', 'Programado', 'Servicio programado para atención en fecha específica', 0, 1, 2),
('ASIGNADO', 'Asignado', 'Servicio asignado a técnico o responsable', 0, 1, 3),
('EN_EJECUCION', 'En Ejecución', 'Servicio en proceso de ejecución o atención', 0, 1, 4),
('FINALIZADO', 'Finalizado', 'Servicio completado técnicamente, pendiente de cierre administrativo', 1, 0, 5),
('CERRADO', 'Cerrado', 'Servicio cerrado administrativamente, proceso completo', 1, 0, 6),
('CANCELADO', 'Cancelado', 'Servicio cancelado o anulado', 1, 0, 7)
ON DUPLICATE KEY UPDATE 
  nombre = VALUES(nombre),
  descripcion = VALUES(descripcion),
  es_final = VALUES(es_final),
  permite_edicion = VALUES(permite_edicion),
  orden = VALUES(orden);

-- Verificar que se insertaron correctamente
SELECT codigo, nombre, es_final, orden FROM estados_base ORDER BY orden;
