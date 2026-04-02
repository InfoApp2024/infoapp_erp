<?php
// autorizar_actividad.php - Marcar actividad como autorizada - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/autorizar_actividad.php', 'authorize_activity');

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
    $autorizada = isset($input['autorizada']) ? (bool) $input['autorizada'] : true;
    $notas = $input['notas'] ?? '';

    if (!$inspeccion_actividad_id) {
        throw new Exception('ID de actividad de inspección requerido');
    }

    // Verificar que la actividad existe y obtener el ID de la inspección y su estado actual
    $stmt_check = $conn->prepare("
        SELECT ia.inspeccion_id, i.estado_id 
        FROM inspecciones_actividades ia
        JOIN inspecciones i ON ia.inspeccion_id = i.id
        WHERE ia.id = ?
    ");
    $stmt_check->bind_param("i", $inspeccion_actividad_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    $actividad_data = $result_check->fetch_assoc();

    if (!$actividad_data) {
        throw new Exception('Actividad de inspección no encontrada');
    }
    $inspeccion_id = $actividad_data['inspeccion_id'];
    $estado_actual_id = $actividad_data['estado_id'];
    $stmt_check->close();

    // Bloquear si la inspección ya está en estado final Y no hay actividades pendientes
    // Si hay actividades pendientes (autorizada=0 y no eliminadas), permitimos autorizar aunque el estado diga "final"
    if (esEstadoFinalInspeccion($conn, $estado_actual_id)) {
        $pendientes = contarActividadesPendientes($conn, $inspeccion_id);
        if ($pendientes <= 0) {
            throw new Exception('La inspección se encuentra en estado final y no tiene actividades pendientes, cree una nueva inspección');
        }
    }

    // Actualizar estado de autorización y usuario (la fecha se pondrá al crear el servicio)
    if ($autorizada) {
        $sql = "UPDATE inspecciones_actividades SET autorizada = ?, autorizado_por_id = ?, notas = ? WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $autorizada_int = 1;
        $stmt->bind_param("iisi", $autorizada_int, $currentUser['id'], $notas, $inspeccion_actividad_id);
    } else {
        $sql = "UPDATE inspecciones_actividades SET autorizada = ?, fecha_autorizacion = NULL, autorizado_por_id = NULL, notas = ? WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $autorizada_int = 0;
        $stmt->bind_param("isi", $autorizada_int, $notas, $inspeccion_actividad_id);
    }

    if (!$stmt->execute()) {
        throw new Exception('Error actualizando actividad: ' . $stmt->error);
    }
    $stmt->close();

    // 6. Verificar si la inspección debe finalizarse
    $resultado_finalizacion = verificarYFinalizarInspeccion($conn, $inspeccion_id, $currentUser['id']);

    sendJsonResponse([
        'success' => true,
        'message' => $autorizada ? 'Actividad autorizada exitosamente' : 'Autorización de actividad removida',
        'data' => [
            'id' => (int) $inspeccion_actividad_id,
            'autorizada' => $autorizada,
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