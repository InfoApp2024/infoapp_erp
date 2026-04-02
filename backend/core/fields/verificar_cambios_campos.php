<?php
require_once __DIR__ . '/../../login/auth_middleware.php';

// Configuración CORS
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $currentUser = optionalAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

function logMessage($message)
{
    error_log(date('Y-m-d H:i:s') . " - VERIFICAR_CAMBIOS: " . $message . "\n", 3, __DIR__ . "/verificar_cambios.log");
}

try {
    logMessage("=== INICIO VERIFICAR CAMBIOS ===");

    if (!isset($_GET['servicio_id'])) {
        throw new Exception('servicio_id es requerido');
    }

    $servicio_id = intval($_GET['servicio_id']);
    $ultimo_timestamp = isset($_GET['ultimo_timestamp']) ? $_GET['ultimo_timestamp'] : null;

    if ($servicio_id <= 0) {
        throw new Exception('servicio_id debe ser mayor a 0');
    }

    logMessage("Servicio ID: $servicio_id, Timestamp cliente: $ultimo_timestamp");

    require __DIR__ . '/../../conexion.php';

    if (!isset($conn)) {
        throw new Exception('Error de conexión a la base de datos');
    }

    // Obtener timestamp más reciente de modificaciones
    $stmt = $conn->prepare("
        SELECT MAX(
            GREATEST(
                IFNULL(vca.fecha_actualizacion, vca.fecha_creacion),
                vca.fecha_creacion
            )
        ) as ultima_modificacion_servidor
        FROM valores_campos_adicionales vca
        WHERE vca.servicio_id = ?
    ");

    if (!$stmt) {
        throw new Exception("Error preparando consulta: " . $conn->error);
    }

    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $resultado = $result->fetch_assoc();

    $ultima_modificacion_servidor = $resultado['ultima_modificacion_servidor'];
    $hay_cambios = true;

    if ($ultimo_timestamp && $ultima_modificacion_servidor) {
        $timestamp_servidor = strtotime($ultima_modificacion_servidor);
        $timestamp_cliente = strtotime($ultimo_timestamp);

        $hay_cambios = $timestamp_servidor > $timestamp_cliente;

        logMessage("Servidor: $timestamp_servidor, Cliente: $timestamp_cliente, Hay cambios: " . ($hay_cambios ? 'SÍ' : 'NO'));
    } else {
        logMessage("Primer acceso o sin datos - hay_cambios: SÍ");
    }

    $response = [
        'success' => true,
        'hay_cambios' => $hay_cambios,
        'ultima_modificacion_servidor' => $ultima_modificacion_servidor,
        'timestamp_verificacion' => date('Y-m-d H:i:s')
    ];

    echo json_encode($response);
    logMessage("Respuesta: hay_cambios = " . ($hay_cambios ? 'true' : 'false'));

} catch (Exception $e) {
    $errorMsg = 'Error verificando cambios: ' . $e->getMessage();
    logMessage("ERROR: " . $errorMsg);

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'hay_cambios' => true // En caso de error, asumir que hay cambios
    ]);
}

logMessage("=== FIN VERIFICAR CAMBIOS ===\n");
?>