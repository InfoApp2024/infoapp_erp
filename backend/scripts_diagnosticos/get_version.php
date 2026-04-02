<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');

/**
 * Script para obtener la versión actual de la aplicación.
 * Puede leer desde el archivo version.json generado por Flutter 
 * o desde una base de datos si se prefiere.
 */

$version_file = __DIR__ . '/../web/version.json';

// Opción A: Leer desde el archivo version.json
if (file_exists($version_file)) {
    $json_content = file_get_contents($version_file);
    echo $json_content;
    exit;
}

// Opción B: Si no existe el archivo, devolver una versión por defecto 
// o consultar la base de datos.
// include_once 'conexion.php';
// $query = "SELECT version FROM app_config LIMIT 1";
// ... logic here ...

echo json_encode([
    "version" => "1.0.0+1",
    "status" => "default",
    "message" => "version.json not found, using default"
]);
?>