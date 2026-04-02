<?php
// backend/geocercas/eliminar.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    require '../conexion.php';

    $data = json_decode(file_get_contents("php://input"), true);

    if (!isset($data['id'])) {
        throw new Exception("ID de geocerca requerido");
    }

    $id = intval($data['id']);

    // Soft delete (cambiar estado a 0)
    $sql = "UPDATE geocercas SET estado = 0 WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        sendJsonResponse([
            'success' => true,
            'message' => 'Geocerca eliminada exitosamente'
        ]);
    } else {
        throw new Exception("Error al eliminar: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
