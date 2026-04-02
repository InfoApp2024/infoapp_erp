<?php
// eliminar.php - Soft delete de inspección - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/eliminar.php', 'delete_inspection');

    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';
    require '../servicio/WebSocketNotifier.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $inspeccion_id = $input['id'] ?? null;

    if (!$inspeccion_id) {
        throw new Exception('ID de inspección requerido');
    }

    // Verificar que la inspección existe
    $stmt_check = $conn->prepare("SELECT id, o_inspe FROM inspecciones WHERE id = ? AND deleted_at IS NULL");
    $stmt_check->bind_param("i", $inspeccion_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        throw new Exception('Inspección no encontrada');
    }

    $inspeccion = $result_check->fetch_assoc();
    $o_inspe = $inspeccion['o_inspe'];
    $stmt_check->close();

    // Soft delete
    $sql = "UPDATE inspecciones SET deleted_at = NOW() WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $inspeccion_id);

    if (!$stmt->execute()) {
        throw new Exception('Error eliminando inspección: ' . $stmt->error);
    }

    // Notificar vía WebSocket
    try {
        $notifier = new WebSocketNotifier();
        $notifier->notificar([
            'tipo' => 'inspeccion_eliminada',
            'inspeccion_id' => $inspeccion_id,
            'o_inspe' => $o_inspe,
            'usuario_id' => $currentUser['id']
        ]);
    } catch (Exception $ws_error) {
        error_log("WebSocket error: " . $ws_error->getMessage());
    }

    sendJsonResponse([
        'success' => true,
        'message' => 'Inspección eliminada exitosamente',
        'data' => [
            'id' => (int) $inspeccion_id,
            'o_inspe' => $o_inspe
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