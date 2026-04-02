<?php
// eliminar.php - Eliminar tarifa ICA
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/ica/eliminar.php', 'delete_ica_tariff');

    require '../../conexion.php';
    $conn->set_charset("utf8mb4");

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input)
        throw new Exception("No se recibieron datos.");

    $id = isset($input['id']) ? (int) $input['id'] : 0;

    if ($id <= 0)
        throw new Exception("El ID de la tarifa es requerido.");

    $sql = "DELETE FROM cnf_tarifas_ica WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Tarifa ICA eliminada correctamente.'));
    } else {
        throw new Exception("Error al eliminar de la base de datos.");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
?>