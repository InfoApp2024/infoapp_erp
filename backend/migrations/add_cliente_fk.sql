-- ============================================
-- MIGRACIÓN: Agregar FK de clientes a equipos y funcionarios
-- Fecha: 2026-02-02
-- Propósito: Establecer relaciones formales entre clientes, equipos y funcionarios
-- ============================================

-- IMPORTANTE: Realizar backup de la base de datos antes de ejecutar este script
-- Comando sugerido: mysqldump -u usuario -p nombre_bd > backup_$(date +%Y%m%d_%H%M%S).sql

START TRANSACTION;

-- ============================================
-- PASO 1: AGREGAR COLUMNAS
-- ============================================

-- Agregar columna cliente_id a equipos
ALTER TABLE equipos 
ADD COLUMN cliente_id INT NULL COMMENT 'FK a tabla clientes' 
AFTER nombre_empresa;

-- Agregar columna cliente_id a funcionario
ALTER TABLE funcionario 
ADD COLUMN cliente_id INT NULL COMMENT 'FK a tabla clientes' 
AFTER empresa;

-- Agregar columna cliente_id a servicios
ALTER TABLE servicios 
ADD COLUMN cliente_id INT NULL COMMENT 'FK a tabla clientes' 
AFTER orden_cliente;

-- ============================================
-- PASO 2: MIGRAR DATOS EXISTENTES
-- ============================================

-- Migrar equipos: hacer match entre nombre_empresa y clientes
UPDATE equipos e
INNER JOIN clientes c ON LOWER(TRIM(e.nombre_empresa)) = LOWER(TRIM(c.nombre_completo))
SET e.cliente_id = c.id
WHERE e.cliente_id IS NULL;

-- Intentar match alternativo por documento/NIT si el nombre no coincide
UPDATE equipos e
INNER JOIN clientes c ON LOWER(TRIM(e.nombre_empresa)) LIKE CONCAT('%', LOWER(TRIM(c.documento_nit)), '%')
SET e.cliente_id = c.id
WHERE e.cliente_id IS NULL AND e.nombre_empresa IS NOT NULL;

-- Migrar funcionarios: hacer match entre empresa y clientes
UPDATE funcionario f
INNER JOIN clientes c ON LOWER(TRIM(f.empresa)) = LOWER(TRIM(c.nombre_completo))
SET f.cliente_id = c.id
WHERE f.cliente_id IS NULL;

-- Intentar match alternativo por documento/NIT
UPDATE funcionario f
INNER JOIN clientes c ON LOWER(TRIM(f.empresa)) LIKE CONCAT('%', LOWER(TRIM(c.documento_nit)), '%')
SET f.cliente_id = c.id
WHERE f.cliente_id IS NULL AND f.empresa IS NOT NULL;

-- Migrar servicios: usar el cliente_id del equipo relacionado
UPDATE servicios s
INNER JOIN equipos e ON s.id_equipo = e.id
SET s.cliente_id = e.cliente_id
WHERE s.cliente_id IS NULL;

-- ============================================
-- PASO 3: CREAR ÍNDICES PARA PERFORMANCE
-- ============================================

-- Índice para equipos
ALTER TABLE equipos 
ADD INDEX idx_equipos_cliente (cliente_id);

-- Índice para funcionarios
ALTER TABLE funcionario 
ADD INDEX idx_funcionario_cliente (cliente_id);

-- Índice para servicios
ALTER TABLE servicios 
ADD INDEX idx_servicios_cliente (cliente_id);

-- ============================================
-- PASO 4: AGREGAR FOREIGN KEY CONSTRAINTS (OPCIONAL)
-- ============================================

-- NOTA: Estas constraints están comentadas por defecto para evitar errores
-- si existen datos huérfanos. Descomentarlas solo si estás seguro de que
-- todos los registros tienen cliente_id válido o pueden ser NULL.

-- ALTER TABLE equipos 
-- ADD CONSTRAINT fk_equipos_cliente 
--     FOREIGN KEY (cliente_id) 
--     REFERENCES clientes(id) 
--     ON DELETE SET NULL 
--     ON UPDATE CASCADE;

-- ALTER TABLE funcionario 
-- ADD CONSTRAINT fk_funcionario_cliente 
--     FOREIGN KEY (cliente_id) 
--     REFERENCES clientes(id) 
--     ON DELETE SET NULL 
--     ON UPDATE CASCADE;

COMMIT;

-- ============================================
-- VERIFICACIÓN POST-MIGRACIÓN
-- ============================================

-- Mostrar equipos sin cliente asignado
SELECT 
    '=== EQUIPOS SIN CLIENTE ===' as info,
    COUNT(*) as total
FROM equipos 
WHERE cliente_id IS NULL;

SELECT 
    id, 
    nombre, 
    nombre_empresa, 
    cliente_id 
FROM equipos 
WHERE cliente_id IS NULL 
LIMIT 10;

-- Mostrar funcionarios sin cliente asignado
SELECT 
    '=== FUNCIONARIOS SIN CLIENTE ===' as info,
    COUNT(*) as total
FROM funcionario 
WHERE cliente_id IS NULL;

SELECT 
    id, 
    nombre, 
    empresa, 
    cliente_id 
FROM funcionario 
WHERE cliente_id IS NULL 
LIMIT 10;

-- Estadísticas de migración
SELECT 
    '=== ESTADÍSTICAS DE MIGRACIÓN ===' as info;

SELECT 
    'Equipos' as tabla,
    COUNT(*) as total_registros,
    SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END) as con_cliente,
    SUM(CASE WHEN cliente_id IS NULL THEN 1 ELSE 0 END) as sin_cliente,
    ROUND(SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as porcentaje_migrado
FROM equipos
UNION ALL
SELECT 
    'Funcionarios',
    COUNT(*),
    SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END),
    SUM(CASE WHEN cliente_id IS NULL THEN 1 ELSE 0 END),
    ROUND(SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM funcionario;

SELECT 
    'Servicios' as tabla,
    COUNT(*) as total_registros,
    SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END) as con_cliente,
    SUM(CASE WHEN cliente_id IS NULL THEN 1 ELSE 0 END) as sin_cliente,
    ROUND(SUM(CASE WHEN cliente_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2)
FROM servicios;

-- Verificar que los índices se crearon correctamente
SHOW INDEX FROM equipos WHERE Key_name = 'idx_equipos_cliente';
SHOW INDEX FROM funcionario WHERE Key_name = 'idx_funcionario_cliente';

-- ============================================
-- NOTAS IMPORTANTES
-- ============================================

-- 1. DATOS HUÉRFANOS: Los registros sin cliente_id pueden ser:
--    - Registros antiguos sin empresa asignada
--    - Nombres de empresa que no coinciden exactamente con clientes
--    - Solución: Crear interfaz administrativa para asignar manualmente

-- 2. RETROCOMPATIBILIDAD: Los campos nombre_empresa y empresa se mantienen
--    para compatibilidad con código existente durante el período de transición

-- 3. ROLLBACK: Si necesitas revertir esta migración:
--    ALTER TABLE equipos DROP INDEX idx_equipos_cliente;
--    ALTER TABLE equipos DROP COLUMN cliente_id;
--    ALTER TABLE funcionario DROP INDEX idx_funcionario_cliente;
--    ALTER TABLE funcionario DROP COLUMN cliente_id;
--    ALTER TABLE servicios DROP INDEX idx_servicios_cliente;
--    ALTER TABLE servicios DROP COLUMN cliente_id;
