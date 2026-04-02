<?php
// evidencias/eliminar.php - Eliminar evidencia - Protegido con JWT

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/evidencias/eliminar.php', 'delete_evidence');

    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $evidencia_id = $input['id'] ?? null;

    if (!$evidencia_id) {
        throw new Exception('ID de evidencia requerido');
    }

    // Obtener datos de la evidencia
    $stmt_check = $conn->prepare("SELECT ruta_imagen FROM inspecciones_evidencias WHERE id = ?");
    $stmt_check->bind_param("i", $evidencia_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        throw new Exception('Evidencia no encontrada');
    }

    $evidencia = $result_check->fetch_assoc();
    $ruta_imagen = $evidencia['ruta_imagen'];
    $stmt_check->close();

    // Eliminar registro de la base de datos
    $sql = "DELETE FROM inspecciones_evidencias WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $evidencia_id);

    if (!$stmt->execute()) {
        throw new Exception('Error eliminando evidencia: ' . $stmt->error);
    }

    // Eliminar archivo físico si existe
    if (file_exists($ruta_imagen)) {
        unlink($ruta_imagen);
    }

    sendJsonResponse([
        'success' => true,
        'message' => 'Evidencia eliminada exitosamente',
        'data' => [
            'id' => (int) $evidencia_id
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