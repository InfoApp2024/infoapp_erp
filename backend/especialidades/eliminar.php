<?php
// eliminar.php - Eliminar especialidad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (empty($input['id'])) {
        throw new Exception('ID requerido');
    }

    $id = (int)$input['id'];

    // Verificar si está en uso (opcional, pero recomendado)
    // Por ahora dejamos que el ON DELETE RESTRICT o CASCADE de la DB maneje, 
    // pero como pusimos CASCADE en init.sql, se borrarán las tarifas asociadas.
    
    $stmt = $conn->prepare("DELETE FROM especialidades WHERE id = ?");
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Especialidad eliminada'));
    } else {
        throw new Exception("Error al eliminar: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
