-- backend/setup/create_full_admin.sql
-- Script para crear manualmente el usuario administrador y asignar permisos

-- 1. Establecer variables
SET @username = 'administrator';
SET @password_hash = '$2y$10$j0gm530hlCGU1PCjdgZFHuh4JjJtPtMNV06hG6BAmjEwCa0wqAC5i'; -- Hash para 'ABCD1234'
SET @email = 'admin@admin.com';
SET @nombre_cliente = 'Administrador Sistema';
SET @rol = 'admin';

-- 2. Asegurar limpieza de duplicados si el UNIQUE INDEX no existiera o fallara
DELETE FROM usuarios 
WHERE NOMBRE_USER = @username 
AND id NOT IN (SELECT * FROM (SELECT MIN(id) FROM usuarios WHERE NOMBRE_USER = @username) as tmp);

-- 3. Insertar o Actualizar Usuario
INSERT INTO usuarios (
    NOMBRE_USER, CONTRASEÑA, TIPO_ROL, NOMBRE_CLIENTE, 
    CORREO, NIT, DIRECCION, TELEFONO, regimen_tributario, 
    SITIO_WEB, RESOLUCION_DIAN, INSTAGRAM, FACEBOOK, WHATSAPP, 
    NOMBRE_CONTACTO, CIUDAD, ESTADO_USER, ID_REGISTRO
) VALUES (
    @username, 
    @password_hash, 
    @rol, 
    '{{NOMBRE_CLIENTE}}', 
    '{{CORREO}}', 
    '{{NIT}}', 
    '{{DIRECCION}}', 
    '{{TELEFONO}}', 
    '{{REGIMEN}}', 
    '{{SITIO_WEB}}', 
    '{{RESOLUCION}}', 
    '{{INSTAGRAM}}', 
    '{{FACEBOOK}}', 
    '{{WHATSAPP}}', 
    '{{CONTACTO}}', 
    '{{CIUDAD}}', 
    'activo', 
    '{{ID_REGISTRO}}'
) ON DUPLICATE KEY UPDATE 
    CONTRASEÑA = @password_hash,
    TIPO_ROL = @rol,
    NOMBRE_CLIENTE = '{{NOMBRE_CLIENTE}}',
    CORREO = '{{CORREO}}',
    NIT = '{{NIT}}',
    DIRECCION = '{{DIRECCION}}',
    TELEFONO = '{{TELEFONO}}',
    regimen_tributario = '{{REGIMEN}}',
    SITIO_WEB = '{{SITIO_WEB}}',
    RESOLUCION_DIAN = '{{RESOLUCION}}',
    INSTAGRAM = '{{INSTAGRAM}}',
    FACEBOOK = '{{FACEBOOK}}',
    WHATSAPP = '{{WHATSAPP}}',
    NOMBRE_CONTACTO = '{{CONTACTO}}',
    CIUDAD = '{{CIUDAD}}',
    ESTADO_USER = 'activo',
    ID_REGISTRO = '{{ID_REGISTRO}}';

-- 4. Obtener ID del usuario
SET @user_id = (SELECT id FROM usuarios WHERE NOMBRE_USER = @username LIMIT 1);

-- 5. Limpiar permisos antiguos
DELETE FROM user_permissions WHERE user_id = @user_id;

-- 6. Insertar Permisos (Listar, Crear, Actualizar, Eliminar, Ver, Exportar) para todos los módulos
INSERT INTO user_permissions (user_id, module, action, allowed)
SELECT @user_id, modulos.nombre, acciones.nombre, 1
FROM 
    (SELECT 'usuarios' as nombre 
     UNION SELECT 'servicios' 
     UNION SELECT 'inventario' 
     UNION SELECT 'equipos' 
     UNION SELECT 'branding' 
     UNION SELECT 'campos_adicionales' 
     UNION SELECT 'estados_transiciones' 
     UNION SELECT 'geocerca' 
     UNION SELECT 'clientes' 
     UNION SELECT 'dashboard'
     UNION SELECT 'inspecciones'
     UNION SELECT 'plantillas'
     UNION SELECT 'ia'
     UNION SELECT 'chatbot'
     UNION SELECT 'servicios_tipo_mantenimiento'
     UNION SELECT 'servicios_centro_costo'
     UNION SELECT 'gestion_financiera'
     UNION SELECT 'servicios_actividades') as modulos,
    (SELECT 'listar' as nombre 
     UNION SELECT 'crear' 
     UNION SELECT 'actualizar' 
     UNION SELECT 'eliminar' 
     UNION SELECT 'ver' 
     UNION SELECT 'exportar'
     UNION SELECT 'descargar'
     UNION SELECT 'devolver') as acciones;

-- 7. Caso especial para auditoría administrativa
INSERT IGNORE INTO user_permissions (user_id, module, action, allowed)
VALUES (@user_id, 'admin', 'ver', 1), (@user_id, 'admin', 'admin', 1);

-- Confirmación
SELECT CONCAT('Usuario ', @username, ' configurado con ID: ', @user_id) as Resultado;
SELECT * FROM user_permissions WHERE user_id = @user_id;
