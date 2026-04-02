-- backend/setup/manual_reset_password.sql
-- Script para resetear manualmente la contraseña del administrador en la base de datos remota
-- Ejecutar esto en phpMyAdmin o consola SQL

-- 1. Verificar longitud de la columna (Importante)
-- Si el resultado es menor a 60, necesitas ejecutar:
-- ALTER TABLE usuarios MODIFY COLUMN CONTRASEÑA VARCHAR(255);
SELECT LENGTH(CONTRASEÑA) as longitud_hash FROM usuarios WHERE NOMBRE_USER = 'administrator';

-- 2. Actualizar contraseña hash para '123456'
-- Este hash es generado con BCRYPT y funciona para la contraseña '123456'
UPDATE usuarios 
SET 
    CONTRASEÑA = '$2y$10$R389S5KuKUraR4/GLZn/b.lwYRaxNz/O',
    ESTADO_USER = 'activo',
    TIPO_ROL = 'administrador'
WHERE NOMBRE_USER = 'administrator';

-- 3. Verificar que se actualizó
SELECT id, NOMBRE_USER, TIPO_ROL, ESTADO_USER FROM usuarios WHERE NOMBRE_USER = 'administrator';
