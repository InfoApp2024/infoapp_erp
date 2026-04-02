-- PASO 1: Verificar si hay duplicados antes de crear el constraint
SELECT modulo, estado_origen_id, estado_destino_id, COUNT(*) as total
FROM transiciones_estado
GROUP BY modulo, estado_origen_id, estado_destino_id
HAVING COUNT(*) > 1;

-- PASO 2 (ejecutar solo si PASO 1 devuelve 0 filas):
ALTER TABLE transiciones_estado
  ADD UNIQUE KEY uq_transicion_modulo (modulo, estado_origen_id, estado_destino_id);

-- PASO 3: Confirmar que el constraint existe
SHOW INDEX FROM transiciones_estado WHERE Key_name = 'uq_transicion_modulo';
