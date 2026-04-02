<?php
// evidencias/actualizar_comentario.php - Actualizar comentario de evidencia - Protegido con JWT

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/evidencias/actualizar_comentario.php', 'update_evidence_comment');

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $evidencia_id = $input['id'] ?? null;
    $comentario = $input['comentario'] ?? '';

    if (!$evidencia_id) {
        throw new Exception('ID de evidencia requerido');
    }

    // Verificar que la evidencia existe
    $stmt_check = $conn->prepare("SELECT id FROM inspecciones_evidencias WHERE id = ?");
    $stmt_check->bind_param("i", $evidencia_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        throw new Exception('Evidencia no encontrada');
    }
    $stmt_check->close();

    // Actualizar comentario
    $sql = "UPDATE inspecciones_evidencias SET comentario = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("si", $comentario, $evidencia_id);

    if (!$stmt->execute()) {
        throw new Exception('Error actualizando comentario: ' . $stmt->error);
    }

    sendJsonResponse([
        'success' => true,
        'message' => 'Comentario actualizado exitosamente',
        'data' => [
            'id' => (int) $evidencia_id,
            'comentario' => $comentario
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>