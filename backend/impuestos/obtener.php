<?php
// obtener.php - Obtener impuesto por ID
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/obtener.php', 'get_tax');

    require '../conexion.php';

    if (!isset($_GET['id'])) {
        throw new Exception('ID requerido');
    }

    $id = (int)$_GET['id'];

    $sql = "SELECT * FROM impuestos_config WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($row = $result->fetch_assoc()) {
        $row['id'] = (int)$row['id'];
        $row['porcentaje'] = (float)$row['porcentaje'];
        $row['base_minima_uvt'] = (float)$row['base_minima_uvt'];
        $row['estado'] = (int)$row['estado'];
        sendJsonResponse(successResponse($row));
    } else {
        sendJsonResponse(errorResponse('Impuesto no encontrado'), 404);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
