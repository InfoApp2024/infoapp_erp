<?php
// vincular_servicio.php - Vincular actividad de inspección a servicio - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/actividades/vincular_servicio.php', 'link_activity_to_service');

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../../conexion.php';
    require '../../servicio/WebSocketNotifier.php';

    // Leer input JSON
    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    // Extraer datos
    $actividad_inspeccion_id = $input['actividad_inspeccion_id'] ?? null;
    $servicio_id = $input['servicio_id'] ?? null;
    $usuario_id = $currentUser['id'];

    // Validaciones
    if (!$actividad_inspeccion_id) {
        throw new Exception('actividad_inspeccion_id es requerido');
    }
    if (!$servicio_id) {
        throw new Exception('servicio_id es requerido');
    }

    // Iniciar transacción
    $conn->begin_transaction();

    try {
        // Verificar que la actividad existe y no está eliminada
        $stmt_check = $conn->prepare(
            "SELECT id, inspeccion_id, actividad_id, servicio_id 
             FROM inspecciones_actividades 
             WHERE id = ? AND deleted_at IS NULL"
        );
        $stmt_check->bind_param("i", $actividad_inspeccion_id);
        $stmt_check->execute();
        $result = $stmt_check->get_result();

        if ($result->num_rows === 0) {
            throw new Exception('Actividad de inspección no encontrada o eliminada');
        }

        $actividad = $result->fetch_assoc();
        $stmt_check->close();

        // Verificar si ya tiene un servicio asignado
        if ($actividad['servicio_id'] !== null) {
            throw new Exception('Esta actividad ya está vinculada al servicio #' . $actividad['servicio_id']);
        }

        // Actualizar servicio_id
        $stmt_update = $conn->prepare(
            "UPDATE inspecciones_actividades 
             SET servicio_id = ?, updated_at = NOW() 
             WHERE id = ?"
        );
        $stmt_update->bind_param("ii", $servicio_id, $actividad_inspeccion_id);

        if (!$stmt_update->execute()) {
            throw new Exception('Error vinculando actividad: ' . $stmt_update->error);
        }

        $stmt_update->close();

        // Commit de la transacción
        $conn->commit();

        // Notificar vía WebSocket
        try {
            $notifier = new WebSocketNotifier();
            $notifier->notificar([
                'tipo' => 'actividad_vinculada',
                'inspeccion_id' => $actividad['inspeccion_id'],
                'actividad_id' => $actividad['actividad_id'],
                'servicio_id' => $servicio_id,
                'usuario_id' => $usuario_id
            ]);
        } catch (Exception $ws_error) {
            // No fallar si el WebSocket falla
            error_log("WebSocket error: " . $ws_error->getMessage());
        }

        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => 'Actividad vinculada al servicio exitosamente',
            'data' => [
                'actividad_inspeccion_id' => (int) $actividad_inspeccion_id,
                'servicio_id' => (int) $servicio_id,
                'inspeccion_id' => (int) $actividad['inspeccion_id']
            ]
        ], 200);

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_check))
        $stmt_check->close();
    if (isset($stmt_update))
        $stmt_update->close();
    if (isset($conn))
        $conn->close();
}
?>