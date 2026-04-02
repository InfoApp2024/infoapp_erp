<?php
// Test CORS básico
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header('Content-Type: application/json; charset=utf-8');

// Manejar OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Respuesta de prueba
echo json_encode([
    'success' => true,
    'message' => 'CORS test OK',
    'timestamp' => date('Y-m-d H:i:s')
]);
?>