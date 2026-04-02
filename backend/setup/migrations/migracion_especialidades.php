<?php
// backend/migracion_especialidades.php
// Script para aplicar los cambios en la base de datos

header('Content-Type: text/plain');

// Incluir conexión (ajustar path si es necesario)
// Si este script está en backend/, la conexión está en backend/conexion.php
// Pero conexion.php usa ../login/auth_middleware.php? No, conexion.php es simple.
// Vamos a ver conexion.php para asegurar.
// conexion.php suele incluir credenciales.

if (file_exists('conexion.php')) {
    require '../../conexion.php';
} elseif (file_exists('../conexion.php')) {
    include '../conexion.php';
} else {
    die("No se encontró conexion.php");
}

echo "Iniciando migración...\n";

// 1. Crear tablas desde init.sql
$sqlInitPath = 'especialidades/init.sql';
if (!file_exists($sqlInitPath)) {
    die("No se encontró $sqlInitPath\n");
}

$sqlContent = file_get_contents($sqlInitPath);

// Separar queries si hay múltiples (init.sql tiene varios CREATE TABLE)
// multi_query ejecuta todo.
if ($conn->multi_query($sqlContent)) {
    echo "✅ Tablas creadas/verificadas (especialidades, cliente_perfiles).\n";
    // Consumir resultados para liberar conexión
    while ($conn->next_result()) {
        ;
    }
} else {
    echo "❌ Error creando tablas: " . $conn->error . "\n";
}

// 2. Renombrar columna valor_mo a perfil en clientes
// Verificar si existe valor_mo
$res = $conn->query("SHOW COLUMNS FROM clientes LIKE 'valor_mo'");
if ($res && $res->num_rows > 0) {
    echo "Detectada columna 'valor_mo'. Renombrando a 'perfil'...\n";
    $sqlAlter = "ALTER TABLE clientes CHANGE valor_mo perfil VARCHAR(100) NULL COMMENT 'Nombre del perfil principal'";
    if ($conn->query($sqlAlter)) {
        echo "✅ Columna renombrada a 'perfil'.\n";
    } else {
        echo "❌ Error renombrando columna: " . $conn->error . "\n";
    }
} else {
    // Verificar si ya existe perfil
    $resP = $conn->query("SHOW COLUMNS FROM clientes LIKE 'perfil'");
    if ($resP && $resP->num_rows > 0) {
        echo "ℹ️ La columna 'perfil' ya existe.\n";
    } else {
        echo "⚠️ No se encontró 'valor_mo' ni 'perfil'. Verifique la estructura de 'clientes'.\n";
    }
}

echo "Migración completada.\n";
?>