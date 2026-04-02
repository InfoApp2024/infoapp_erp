-- Script de diagnóstico para verificar estructura de tablas
-- Ejecuta este script para ver qué columnas existen realmente

-- Ver estructura de estados_proceso
DESCRIBE estados_proceso;

-- Ver si existe tabla estados_base
SHOW TABLES LIKE 'estados_base';

-- Si existe, ver su estructura
-- DESCRIBE estados_base;
