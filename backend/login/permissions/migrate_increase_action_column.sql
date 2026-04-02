-- ============================================
-- Migración: Aumentar tamaño de columna action
-- ============================================
-- Fecha: 2026-02-04
-- Propósito: Permitir acciones más largas como 'configurar_columnas'
--
-- PROBLEMA:
-- La columna 'action' en user_permissions es VARCHAR(15)
-- pero necesitamos almacenar 'configurar_columnas' (20 caracteres)
--
-- SOLUCIÓN:
-- Aumentar el tamaño a VARCHAR(50) para soportar acciones futuras
-- ============================================

-- Modificar la columna action para aumentar su tamaño
ALTER TABLE user_permissions 
MODIFY COLUMN action VARCHAR(50) NOT NULL;
