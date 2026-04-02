<?php
header("Content-Type: text/plain");

require_once '../login/auth_middleware.php';
$currentUser = requireAuth();

echo "INICIO_RESPUESTA\n";
echo "REQUEST_METHOD: " . $_SERVER['REQUEST_METHOD'] . "\n";
echo "CONTENT_TYPE: " . ($_SERVER['CONTENT_TYPE'] ?? 'no definido') . "\n";
echo "INPUT_RAW: " . file_get_contents('php://input') . "\n";
echo "PHP_VERSION: " . phpversion() . "\n";
echo "ARCHIVOS_EXISTENTES:\n";
echo "- conexion.php: " . (file_exists('conexion.php') ? 'SÍ' : 'NO') . "\n";
echo "- WebSocketNotifier.php: " . (file_exists('WebSocketNotifier.php') ? 'SÍ' : 'NO') . "\n";

// Probar JSON simple
$test_json = json_encode(['test' => true, 'message' => 'Prueba JSON']);
echo "TEST_JSON: " . $test_json . "\n";

echo "FIN_RESPUESTA\n";
?>