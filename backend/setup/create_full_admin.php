<?php
// backend/setup/create_full_admin.php
// Script para crear un usuario administrador con permisos totales
// Uso: Abrir en navegador o ejecutar por CLI

error_reporting(E_ALL);
ini_set('display_errors', 1);

echo "<h1>Creación de Usuario Administrador</h1>";
echo "<pre>";

// 1. Conexión a Base de Datos
$possiblePaths = [
    '../conexion.php',
    '../../conexion.php',
    'conexion.php'
];

$conn = null;
foreach ($possiblePaths as $path) {
    if (file_exists($path)) {
        echo "Conectando usando: $path\n";
        require_once $path;
        break;
    }
}

if (!$conn) {
    die("❌ Error: No se encontró conexion.php");
}

// 2. Datos del Usuario
$username = 'administrator';
$passwordPlain = 'ABCD1234';
$passwordHash = password_hash($passwordPlain, PASSWORD_BCRYPT);
$email = 'admin@admin.com'; // Correo dummy
$role = 'admin'; // Rol admin
$nombreCliente = 'Administrador Sistema'; // Nombre para mostrar

// 3. Verificar si existe
$sqlCheck = "SELECT id FROM usuarios WHERE NOMBRE_USER = ?";
$stmtCheck = $conn->prepare($sqlCheck);
$stmtCheck->bind_param("s", $username);
$stmtCheck->execute();
$resCheck = $stmtCheck->get_result();

$userId = null;

if ($resCheck->num_rows > 0) {
    $row = $resCheck->fetch_assoc();
    $userId = $row['id'];
    echo "⚠️ El usuario '$username' ya existe (ID: $userId). Actualizando contraseña y rol...\n";

    // Actualizar contraseña y rol
    $sqlUpdate = "UPDATE usuarios SET CONTRASEÑA = ?, TIPO_ROL = ?, ESTADO_USER = 'activo' WHERE id = ?";
    $stmtUpdate = $conn->prepare($sqlUpdate);
    $stmtUpdate->bind_param("ssi", $passwordHash, $role, $userId);
    if ($stmtUpdate->execute()) {
        echo "✅ Usuario actualizado.\n";
    } else {
        die("❌ Error actualizando usuario: " . $conn->error);
    }
} else {
    echo "📝 Creando usuario '$username'...\n";

    // Insertar nuevo usuario
    // Nota: Ajusta los campos según tu tabla real si faltan columnas por defecto
    $sqlInsert = "INSERT INTO usuarios (
        NOMBRE_USER, CONTRASEÑA, TIPO_ROL, NOMBRE_CLIENTE, 
        CORREO, NIT, ESTADO_USER, ID_REGISTRO
    ) VALUES (?, ?, ?, ?, ?, '000000000', 'activo', 'dev')";

    $stmtInsert = $conn->prepare($sqlInsert);
    $stmtInsert->bind_param("sssss", $username, $passwordHash, $role, $nombreCliente, $email);

    if ($stmtInsert->execute()) {
        $userId = $conn->insert_id;
        echo "✅ Usuario creado con ID: $userId\n";
    } else {
        die("❌ Error creando usuario: " . $stmtInsert->error . "\n" . $conn->error);
    }
}

// 4. Asignar Permisos Totales
echo "🔧 Asignando permisos...\n";

// Definir módulos requeridos
$modules = [
    'usuarios',
    'servicios',
    'inventario',
    'equipos',
    'branding',
    'adicionales',
    'estado',
    'geocerca',
    'clientes',
    'dashboard',
    'admin' // Siempre útil para admin
];

$actions = ['listar', 'crear', 'actualizar', 'eliminar', 'ver', 'exportar'];

// Limpiar permisos anteriores
$conn->query("DELETE FROM user_permissions WHERE user_id = $userId");

// Preparar insert
$stmtPerm = $conn->prepare("INSERT INTO user_permissions (user_id, module, action, allowed) VALUES (?, ?, ?, 1)");

$count = 0;
foreach ($modules as $mod) {
    foreach ($actions as $act) {
        $stmtPerm->bind_param("iss", $userId, $mod, $act);
        if ($stmtPerm->execute()) {
            $count++;
        }
    }
}

echo "✅ Se asignaron $count permisos al usuario '$username'.\n";
echo "\n============================================\n";
echo "🎉 PROCESO FINALIZADO EXITOSAMENTE\n";
echo "Usuario: $username\n";
echo "Contraseña: $passwordPlain\n";
echo "============================================\n";

echo "</pre>";
?>