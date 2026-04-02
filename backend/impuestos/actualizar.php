<?php
// actualizar.php - Actualizar impuesto
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/actualizar.php', 'update_tax');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['id'])) {
        throw new Exception('ID de impuesto requerido');
    }

    $id = (int) $input['id'];
    $nombre_impuesto = trim($input['nombre_impuesto']);
    $tipo_impuesto = trim($input['tipo_impuesto']);
    $porcentaje = (float) $input['porcentaje'];
    $base_minima_pesos = (float) $input['base_minima_pesos'];
    $descripcion = isset($input['descripcion']) ? trim($input['descripcion']) : null;
    $estado = isset($input['estado']) ? (int) $input['estado'] : 1;

    $sql = "UPDATE impuestos_config SET nombre_impuesto=?, tipo_impuesto=?, porcentaje=?, base_minima_pesos=?, descripcion=?, estado=? WHERE id=?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssddsii", $nombre_impuesto, $tipo_impuesto, $porcentaje, $base_minima_pesos, $descripcion, $estado, $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Impuesto actualizado correctamente'));
    } else {
        throw new Exception("Error al actualizar impuesto");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
