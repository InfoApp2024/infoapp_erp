<?php
// backend/accounting/registrar_auditoria.php
// Registra la auditoría financiera de un servicio.
// Solo accesible por usuarios con es_auditor = 1.
// POST { servicio_id: int, comentario?: string }

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/accounting/registrar_auditoria.php', 'registrar_auditoria');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    // 1. Verificar que el usuario autenticado sea auditor
    $stmtEsAuditor = $conn->prepare(
        "SELECT es_auditor, NOMBRE_USER FROM usuarios WHERE id = ? LIMIT 1"
    );
    $stmtEsAuditor->bind_param("i", $currentUser['id']);
    $stmtEsAuditor->execute();
    $usuarioData = $stmtEsAuditor->get_result()->fetch_assoc();
    $stmtEsAuditor->close();

    if (!$usuarioData || (int) $usuarioData['es_auditor'] !== 1) {
        sendJsonResponse(errorResponse(
            'Acceso denegado: solo los auditores pueden registrar auditorías financieras.'
        ), 403);
    }

    // 2. Leer input
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON inválido: ' . json_last_error_msg());
    }

    $servicio_id = isset($input['servicio_id']) ? intval($input['servicio_id']) : null;
    $comentario = isset($input['comentario']) ? trim($input['comentario']) : null;
    $es_excepcion = isset($input['es_excepcion']) ? (intval($input['es_excepcion']) === 1 ? 1 : 0) : 0;

    if (!$servicio_id) {
        sendJsonResponse(errorResponse('servicio_id es requerido'), 400);
    }

    if (empty($comentario)) {
        sendJsonResponse(errorResponse('El comentario de auditoría es obligatorio para la aprobación.'), 400);
    }

    // 3. Verificar que el servicio existe en la tabla principal servicios
    $stmtServicio = $conn->prepare(
        "SELECT id FROM servicios WHERE id = ? LIMIT 1"
    );
    $stmtServicio->bind_param("i", $servicio_id);
    $stmtServicio->execute();
    $servicioExiste = $stmtServicio->get_result()->fetch_assoc();
    $stmtServicio->close();

    if (!$servicioExiste) {
        sendJsonResponse(errorResponse('Servicio no encontrado.'), 404);
    }

    // 4. Obtener el ciclo actual de auditoría para este servicio
    $stmtCiclo = $conn->prepare("SELECT ciclo_actual FROM fac_audit_ciclos WHERE servicio_id = ? LIMIT 1");
    $stmtCiclo->bind_param("i", $servicio_id);
    $stmtCiclo->execute();
    $cicloRow = $stmtCiclo->get_result()->fetch_assoc();
    $stmtCiclo->close();
    $ciclo_actual = $cicloRow ? (int) $cicloRow['ciclo_actual'] : 1;

    // 5. Verificar si ya existe una auditoría para el ciclo actual (evitar duplicados por ciclo)
    $stmtExiste = $conn->prepare(
        "SELECT id FROM fac_auditorias_servicio WHERE servicio_id = ? AND ciclo = ? LIMIT 1"
    );
    $stmtExiste->bind_param("ii", $servicio_id, $ciclo_actual);
    $stmtExiste->execute();
    $yaAuditado = $stmtExiste->get_result()->fetch_assoc();
    $stmtExiste->close();

    if ($yaAuditado) {
        sendJsonResponse(errorResponse(
            'Este servicio ya fue auditado en el ciclo actual. No se permiten auditorías duplicadas.'
        ), 409);
    }

    // 6. Registrar la auditoría con el ciclo actual
    $auditor_id = $currentUser['id'];
    $stmtInsert = $conn->prepare(
        "INSERT INTO fac_auditorias_servicio (servicio_id, auditor_id, comentario, ciclo, es_excepcion)
         VALUES (?, ?, ?, ?, ?)"
    );
    $stmtInsert->bind_param("iisii", $servicio_id, $auditor_id, $comentario, $ciclo_actual, $es_excepcion);

    if (!$stmtInsert->execute()) {
        throw new Exception('Error al registrar la auditoría: ' . $stmtInsert->error);
    }
    $nuevo_id = $conn->insert_id;
    $stmtInsert->close();

    sendJsonResponse([
        'success' => true,
        'message' => 'Auditoría registrada exitosamente.',
        'data' => [
            'auditoria_id' => $nuevo_id,
            'servicio_id' => $servicio_id,
            'auditor_id' => $auditor_id,
            'auditor_nombre' => $usuarioData['NOMBRE_USER'],
            'fecha_auditoria' => date('Y-m-d H:i:s'),
            'comentario' => $comentario,
            'es_excepcion' => $es_excepcion === 1
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
} finally {
    if (isset($stmtEsAuditor))
        $stmtEsAuditor->close();
    if (isset($stmtServicio))
        $stmtServicio->close();
    if (isset($stmtExiste))
        $stmtExiste->close();
    if (isset($stmtInsert))
        $stmtInsert->close();
    if (isset($conn))
        $conn->close();
}
