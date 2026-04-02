<?php
// eliminar.php - Desactivar impuesto
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/eliminar.php', 'delete_tax');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['id'])) {
        throw new Exception('ID de impuesto requerido');
    }

    $id = (int)$input['id'];

    // Soft delete
    $sql = "UPDATE impuestos_config SET estado = 0 WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Impuesto desactivado correctamente'));
    } else {
        throw new Exception("Error al desactivar impuesto");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
