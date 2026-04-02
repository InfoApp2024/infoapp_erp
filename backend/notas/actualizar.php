<?php
// backend/notas/actualizar.php
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') { // Usamos POST para update por simplicidad o PUT
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!isset($input['id']) || !isset($input['nota'])) {
        sendJsonResponse(errorResponse('Faltan datos requeridos'), 400);
    }

    require '../conexion.php';

    $id = intval($input['id']);
    $nota = trim($input['nota']);
    $usuario_id = intval($currentUser['id']);
    
    // Verificar que la nota exista y pertenezca al usuario
    $checkStmt = $conn->prepare("SELECT usuario_id FROM notas WHERE id = ?");
    $checkStmt->bind_param("i", $id);
    $checkStmt->execute();
    $result = $checkStmt->get_result();
    
    if ($result->num_rows === 0) {
        sendJsonResponse(errorResponse('Nota no encontrada'), 404);
    }
    
    $row = $result->fetch_assoc();
    if (intval($row['usuario_id']) !== $usuario_id) {
        sendJsonResponse(errorResponse('No tienes permiso para editar esta nota'), 403);
    }

    // Actualizar
    $updateStmt = $conn->prepare("UPDATE notas SET nota = ? WHERE id = ?");
    $updateStmt->bind_param("si", $nota, $id);
    
    if ($updateStmt->execute()) {
        sendJsonResponse([
            'success' => true,
            'message' => 'Nota actualizada exitosamente'
        ]);
    } else {
        throw new Exception("Error al actualizar la nota: " . $updateStmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
