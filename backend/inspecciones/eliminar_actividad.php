<?php
// eliminar_actividad.php - Eliminar (soft delete) actividad de inspección - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/eliminar_actividad.php', 'delete_activity');

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';
    require 'helpers/inspeccion_helper.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $inspeccion_actividad_id = $input['id'] ?? null;
    $notas = $input['notas'] ?? 'Eliminada desde vista de detalle';

    if (!$inspeccion_actividad_id) {
        throw new Exception('ID de actividad de inspección requerido');
    }

    // Verificar que la actividad existe y obtener el ID de la inspección y su estado actual
    $stmt_check = $conn->prepare("
        SELECT ia.inspeccion_id, ia.servicio_id, i.estado_id 
        FROM inspecciones_actividades ia
        JOIN inspecciones i ON ia.inspeccion_id = i.id
        WHERE ia.id = ? AND ia.deleted_at IS NULL
    ");
    $stmt_check->bind_param("i", $inspeccion_actividad_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    $actividad_data = $result_check->fetch_assoc();

    if (!$actividad_data) {
        throw new Exception('Actividad de inspección no encontrada o ya eliminada');
    }
    $inspeccion_id = $actividad_data['inspeccion_id'];
    $estado_actual_id = $actividad_data['estado_id'];

    // No permitir eliminar si ya tiene un servicio asociado
    if ($actividad_data['servicio_id']) {
        throw new Exception('No se puede eliminar una actividad que ya tiene un servicio asociado');
    }
    $stmt_check->close();

    // Bloquear si la inspección ya está en estado final Y no hay actividades pendientes
    // Si hay actividades pendientes (autorizada=0 y no eliminadas), permitimos eliminar aunque el estado diga "final"
    if (esEstadoFinalInspeccion($conn, $estado_actual_id)) {
        $pendientes = contarActividadesPendientes($conn, $inspeccion_id);
        if ($pendientes <= 0) {
            throw new Exception('La inspección se encuentra en estado final y no tiene actividades pendientes, cree una nueva inspección');
        }
    }

    // Soft delete: actualizar deleted_at, deleted_by y agregar nota
    $sql = "UPDATE inspecciones_actividades SET deleted_at = NOW(), deleted_by = ?, notas = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("isi", $currentUser['id'], $notas, $inspeccion_actividad_id);

    if (!$stmt->execute()) {
        throw new Exception('Error eliminando actividad: ' . $stmt->error);
    }
    $stmt->close();

    // Verificar si la inspección debe finalizarse
    $resultado_finalizacion = verificarYFinalizarInspeccion($conn, $inspeccion_id, $currentUser['id']);

    sendJsonResponse([
        'success' => true,
        'message' => 'Actividad eliminada exitosamente',
        'data' => [
            'id' => (int) $inspeccion_actividad_id,
            'notas' => $notas,
            'inspeccion_finalizada' => $resultado_finalizacion['finalizada'],
            'nuevo_estado_id' => $resultado_finalizacion['nuevo_estado_id'] ?? null
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 400);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>