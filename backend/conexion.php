<?php
mysqli_report(MYSQLI_REPORT_ERROR | MYSQLI_REPORT_STRICT);
// Intentar cargar configuración externa si existe
$configPath = __DIR__ . '/db_config.php';

if (file_exists($configPath)) {
    require_once $configPath;
    $servername = defined('DB_SERVER') ? DB_SERVER : "127.0.0.1";
    $username = defined('DB_USERNAME') ? DB_USERNAME : "u342171239_Test";
    $password = defined('DB_PASSWORD') ? DB_PASSWORD : "Test_2025/-*";
    $database = defined('DB_NAME') ? DB_NAME : "u342171239_InfoApp_Test";
} else {
    // Credenciales por defecto (Development / Fallback)
    $servername = "127.0.0.1";
    $username = "u342171239_Test";
    $password = "Test_2025/-*";
    $database = "u342171239_InfoApp_Test";
}

$conn = new mysqli($servername, $username, $password, $database);

// Verificar conexión
if ($conn->connect_error) {
    // En producción, es mejor no mostrar el error detallado al usuario final, 
    // pero para debugging lo mantenemos o logueamos.
    error_log("Connection failed: " . $conn->connect_error);
    die("Error de conexión a la base de datos.");
}

// ✅ SOLUCIÓN: Forzar charset UTF-8
$conn->set_charset("utf8mb4");

// ✅ CONFIGURACIÓN HORARIA: Bogotá, Colombia (UTC-5)
date_default_timezone_set('America/Bogota');
$conn->query("SET time_zone = '-05:00'");

// ✅ OPCIONAL: Activar modo estricto para detectar problemas
$conn->query("SET sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'");

