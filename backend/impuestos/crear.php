<?php
// crear.php - Crear nuevo impuesto
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/crear.php', 'create_tax');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos JSON inválidos');
    }

    // Validar campos obligatorios
    if (empty($input['nombre_impuesto']) || empty($input['tipo_impuesto'])) {
        throw new Exception("Nombre y tipo de impuesto son obligatorios");
    }

    $nombre_impuesto = trim($input['nombre_impuesto']);
    $tipo_impuesto = trim($input['tipo_impuesto']);
    $porcentaje = isset($input['porcentaje']) ? (float) $input['porcentaje'] : 0.00;
    $base_minima_pesos = isset($input['base_minima_pesos']) ? (float) $input['base_minima_pesos'] : 0.00;
    $descripcion = isset($input['descripcion']) ? trim($input['descripcion']) : null;
    $estado = 1;

    // Insertar
    $sql = "INSERT INTO impuestos_config (nombre_impuesto, tipo_impuesto, porcentaje, base_minima_pesos, descripcion, estado) VALUES (?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssddsi", $nombre_impuesto, $tipo_impuesto, $porcentaje, $base_minima_pesos, $descripcion, $estado);

    if ($stmt->execute()) {
        $id = $stmt->insert_id;
        sendJsonResponse(successResponse(['id' => $id], 'Impuesto creado exitosamente'));
    } else {
        throw new Exception("Error al crear el impuesto: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
