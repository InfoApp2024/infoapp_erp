<?php
// Reportar errores (para debug)
ini_set('display_errors', 0);
error_reporting(E_ALL);

header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

// Manejo de Preflight (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] == 'OPTIONS') {
    http_response_code(200);
    exit();
}

$response = array();

try {
    // 1. Usar conexion_admin.php (Base de datos correcta u342171239_admin_infoapp)
    $connPath = __DIR__ . '/../../conexion_admin.php';
    if (!file_exists($connPath)) {
        throw new Exception("Archivo de conexión no encontrado en: " . $connPath);
    }

    // 2. Incluir conexión
    require_once $connPath;

    // 3. Verificar variable $conn_admin (definida en conexion_admin.php)
    if (!isset($conn_admin)) {
        throw new Exception("Conexión BD no establecida (variable \$conn_admin indefinida).");
    }

    if ($conn_admin->connect_error) {
        throw new Exception("Error de conexión MySQL: " . $conn_admin->connect_error);
    }

    // 4. Procesar Input
    $input = file_get_contents("php://input");
    $data = json_decode($input);

    if (json_last_error() !== JSON_ERROR_NONE) {
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            throw new Exception("Se requiere método POST");
        }
        throw new Exception("JSON inválido recibido");
    }

    if (!isset($data->ID_REGISTRO)) {
        throw new Exception("ID_REGISTRO no proporcionado");
    }

    $id_registro = $conn_admin->real_escape_string($data->ID_REGISTRO);

    // 5. Consulta usando columnas mostradas en captura (nombre_cliente, nit, id_registro)
    // Se mapean a los nombres que espera el frontend (NOMBRE_CLIENTE, NIT)
    $sql = "SELECT nombre_cliente AS NOMBRE_CLIENTE, nit AS NIT, estado FROM clientes WHERE id_registro = '$id_registro'";
    $result = $conn_admin->query($sql);

    if (!$result) {
        throw new Exception("Error SQL: " . $conn_admin->error);
    }

    if ($result->num_rows === 1) {
        $cliente = $result->fetch_assoc();

        // Validar estado
        if ($cliente['estado'] !== 'activo') {
            $response['success'] = false;
            $response['message'] = "El cliente no está activo";
        } else {
            $response['success'] = true;
            $response['cliente'] = $cliente;
        }
    } else {
        $response['success'] = false;
        $response['message'] = "ID de registro no válido";
    }

} catch (Exception $e) {
    http_response_code(200);
    $response['success'] = false;
    $response['message'] = "Error del Servidor: " . $e->getMessage();
    $response['debug_trace'] = $e->getTraceAsString();
}

echo json_encode($response);
?>