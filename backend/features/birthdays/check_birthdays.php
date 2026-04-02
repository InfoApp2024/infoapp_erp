<?php
// backend/features/birthdays/check_birthdays.php
error_reporting(E_ALL);
ini_set('display_errors', 0); // No mostrar errores en output para no romper JSON

header("Access-Control-Allow-Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? '*'));
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

function sendJson($data)
{
    echo json_encode($data);
    exit();
}

try {
    require_once '../../conexion.php'; // Ajustar ruta según estructura: backend/features/birthdays/ -> ../../conexion.php

    if (!isset($conn) || $conn->connect_error) {
        throw new Exception("Error de conexión a la base de datos");
    }

    $sql = "SELECT id, NOMBRE_USER, NOMBRE_CLIENTE, URL_FOTO, FECHA_NACIMIENTO 
            FROM usuarios 
            WHERE MONTH(FECHA_NACIMIENTO) = MONTH(CURRENT_DATE()) 
              AND DAY(FECHA_NACIMIENTO) = DAY(CURRENT_DATE()) 
              AND ESTADO_USER = 'activo'";

    $result = $conn->query($sql);

    if (!$result) {
        throw new Exception("Error en la consulta: " . $conn->error);
    }

    $cumpleaneros = [];
    while ($row = $result->fetch_assoc()) {
        // Procesar URL de foto para asegurar que sea accesible (similar a login.php)
        $urlFoto = $row['URL_FOTO'] ?? null;
        if ($urlFoto && !preg_match('/^http/', $urlFoto)) {
            $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
            // Determinar path base. Asumiendo que este script está en /backend/features/birthdays/
            // y ver_imagen.php está en /backend/login/ o raíz de backend.
            // Mejor usamos ruta absoluta relativa al webroot si es posible, o hardcodeamos si sabemos la estructura.
            // Simplificación: apuntar a login/ver_imagen.php asumiendo estructura estándar
            // backend/login/ver_imagen.php -> la URL final debe ser accesible.
            // Si el script se llama desde la app, la app suele tener la URL base.
            // Retornaremos la ruta tal cual y dejamos que el el frontend construya la URL completa si es relativa,
            // o intentamos construirla aquí.

            // Intento de construcción inteligente:
            // Bajamos 2 niveles para llegar a backend/
            $scriptDir = dirname(dirname(dirname($_SERVER['SCRIPT_NAME'])));
            // Ahora vamos a login/ver_imagen.php
            $basePath = rtrim(str_replace('\\', '/', $scriptDir), '/');
            $urlFoto = $scheme . '://' . $host . $basePath . '/login/ver_imagen.php?ruta=' . $urlFoto;
        }

        $cumpleaneros[] = [
            'id' => (int) $row['id'],
            'usuario' => $row['NOMBRE_USER'],
            'nombre_completo' => $row['NOMBRE_CLIENTE'],
            'url_foto' => $urlFoto
        ];
    }

    sendJson([
        'success' => true,
        'data' => $cumpleaneros
    ]);

} catch (Exception $e) {
    sendJson([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
