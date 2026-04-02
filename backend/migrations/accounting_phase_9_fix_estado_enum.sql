

-- 1. Modificar la columna 'estado' para incluir 'Exitosa'
-- Se mantienen los valores previos ('ACTIVA', 'ANULADA', 'PAGADA') para compatibilidad.
ALTER TABLE fac_facturas 
MODIFY COLUMN estado ENUM('ACTIVA', 'ANULADA', 'PAGADA', 'Exitosa') DEFAULT 'ACTIVA';

-- Nota: Si existen registros con estados inconsistentes, se recomienda normalizarlos.
-- UPDATE fac_facturas SET estado = 'Exitosa' WHERE estado IS NULL;
