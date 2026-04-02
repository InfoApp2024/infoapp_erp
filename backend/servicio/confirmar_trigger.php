<?php
// confirmar_trigger.php - Protegido con JWT
// Endpoint para marcar triggers como confirmados/completados

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/confirmar_trigger.php', 'confirm_trigger');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';

    // PASO 5: Decodificar input
    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $servicio_id = $input['servicio_id'] ?? null;
    $trigger_type = $input['trigger_type'] ?? null; // 'repuestos', 'fotos', 'firma'

    if (!$servicio_id) {
        throw new Exception('servicio_id es requerido');
    }

    if (!$trigger_type) {
        throw new Exception('trigger_type es requerido');
    }

    // PASO 6: Validar que el servicio existe
    $stmt_verify = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE id = ?");
    $stmt_verify->bind_param("i", $servicio_id);
    $stmt_verify->execute();
    $result_verify = $stmt_verify->get_result();
    $row_verify = $result_verify->fetch_assoc();
    $stmt_verify->close();

    if ($row_verify['count'] == 0) {
        throw new Exception('Servicio no encontrado con ID: ' . $servicio_id);
    }

    // PASO 6.5: Verificar si el servicio estÃ¡ en un estado final protegido
    $stmt_check = $conn->prepare("
        SELECT e.estado_base_codigo 
        FROM servicios s
        INNER JOIN estados_proceso e ON s.estado = e.id
        WHERE s.id = ?
    ");
    $stmt_check->bind_param("i", $servicio_id);
    $stmt_check->execute();
    $res_check = $stmt_check->get_result();
    
    if ($row_check = $res_check->fetch_assoc()) {
        $estado_base = $row_check['estado_base_codigo'];
        if (in_array($estado_base, ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'])) {
            throw new Exception("No se pueden confirmar triggers de un servicio en estado final ($estado_base).");
        }
    }
    $stmt_check->close();

    // PASO 7: Mapear tipo de trigger a campo de base de datos
    $field_map = [
        'repuestos' => 'suministraron_repuestos',
        'fotos' => 'fotos_confirmadas',
        'firma' => 'firma_confirmada',
        'personal' => 'personal_confirmado'
    ];

    if (!isset($field_map[$trigger_type])) {
        throw new Exception('Tipo de trigger inválido: ' . $trigger_type);
    }

    $field = $field_map[$trigger_type];

    // PASO 8: Validar que existan ítems antes de confirmar
    $validation_queries = [
        'repuestos' => "SELECT COUNT(*) as count FROM servicio_repuestos WHERE servicio_id = ?",
        'fotos' => "SELECT COUNT(*) as count FROM fotos_servicio WHERE servicio_id = ?",
        'firma' => "SELECT COUNT(*) as count FROM firmas WHERE id_servicio = ?",
        'personal' => "SELECT COUNT(*) as count FROM servicio_staff WHERE servicio_id = ?"
    ];

    if (isset($validation_queries[$trigger_type])) {
        $stmt_validate = $conn->prepare($validation_queries[$trigger_type]);
        $stmt_validate->bind_param("i", $servicio_id);
        $stmt_validate->execute();
        $result_validate = $stmt_validate->get_result();
        $row_validate = $result_validate->fetch_assoc();
        $stmt_validate->close();

        if ($row_validate['count'] == 0) {
            $messages = [
                'repuestos' => 'No se puede confirmar. Debe agregar al menos un repuesto antes de confirmar.',
                'fotos' => 'No se puede confirmar. Debe subir al menos una foto antes de confirmar.',
                'firma' => 'No se puede confirmar. Debe obtener la firma del cliente antes de confirmar.',
                'personal' => 'No se puede confirmar. Debe asignar al menos un técnico antes de confirmar.'
            ];
            throw new Exception($messages[$trigger_type]);
        }
    }

    // PASO 8.5: Validar campos adicionales obligatorios del estado actual
    // Esto previene que el trigger SQL cambie el estado sin validar campos requeridos
    $stmt_estado = $conn->prepare("SELECT estado FROM servicios WHERE id = ?");
    $stmt_estado->bind_param("i", $servicio_id);
    $stmt_estado->execute();
    $result_estado = $stmt_estado->get_result();
    $servicio_data = $result_estado->fetch_assoc();
    $stmt_estado->close();

    if ($servicio_data) {
        $estado_actual = $servicio_data['estado'];

        // VALIDAR CAMPOS OBLIGATORIOS (Centralizado)
        require_once './helpers/validacion_helper.php';
        try {
            checkRequiredFields($conn, $servicio_id, $estado_actual, "No se puede confirmar.");
        } catch (Exception $e_val) {
            throw new Exception($e_val->getMessage());
        }
    }

    // PASO 9: Actualizar flag de confirmación
    $sql = "UPDATE servicios 
            SET $field = 1, 
                usuario_ultima_actualizacion = ?, 
                fecha_actualizacion = NOW() 
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Error preparando consulta: ' . $conn->error);
    }

    $stmt->bind_param("ii", $currentUser['id'], $servicio_id);

    if (!$stmt->execute()) {
        throw new Exception('Error ejecutando consulta: ' . $stmt->error);
    }

    $stmt->close();

    // PASO 10: Evaluar triggers automáticos (ej: cambio de estado al confirmar repuestos)
    require_once '../workflow/workflow_helper.php';
    $workflow_res = WorkflowHelper::evaluarTriggersAutomaticos($conn, $servicio_id, $currentUser['id']);

    // PASO 11: Respuesta exitosa
    sendJsonResponse([
        'success' => true,
        'message' => 'Confirmación registrada exitosamente',
        'data' => [
            'servicio_id' => (int) $servicio_id,
            'trigger_type' => $trigger_type,
            'field_updated' => $field,
            'confirmed_by_user' => $currentUser['usuario'],
            'confirmed_by_role' => $currentUser['rol'],
            'workflow' => $workflow_res // ✅ Informar al frontend si hubo cambio de estado
        ]
    ], 200);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt)) {
        $stmt->close();
    }
    if (isset($conn)) {
        $conn->close();
    }
}
?>