<?php
// backend/operaciones/actualizar_operacion.php
require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación JWT
    $currentUser = requireAuth();

    // 2. Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // 3. Obtener datos
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (!isset($data['id'])) {
        sendJsonResponse(errorResponse('ID de operación no proporcionado'), 400);
    }

    $id = intval($data['id']);

    // Conexión a BD
    require '../conexion.php';

    // 3.5. Obtener permisos del usuario (necesarios para validaciones de estado)
    $stmt_user_perm = $conn->prepare("SELECT can_edit_closed_ops FROM usuarios WHERE id = ?");
    $stmt_user_perm->bind_param("i", $currentUser['id']);
    $stmt_user_perm->execute();
    $res_user_perm = $stmt_user_perm->get_result();
    $user_perm = $res_user_perm->fetch_assoc();
    $can_edit_closed_ops = ($user_perm && (int)$user_perm['can_edit_closed_ops'] === 1);
    $stmt_user_perm->close();

    // 3.6. Verificar si el servicio está en un estado final o terminal
    $stmt_check_service = $conn->prepare("
        SELECT e.estado_base_codigo 
        FROM operaciones o
        INNER JOIN servicios s ON o.servicio_id = s.id
        INNER JOIN estados_proceso e ON s.estado = e.id
        WHERE o.id = ?
    ");
    $stmt_check_service->bind_param("i", $id);
    $stmt_check_service->execute();
    $res_check_service = $stmt_check_service->get_result();

    if ($row_service = $res_check_service->fetch_assoc()) {
        $estado_base = strtoupper($row_service['estado_base_codigo']);
        
        // ESTADOS TERMINALES ABSOLUTOS: No se editan nunca
        if (in_array($estado_base, ['LEGALIZADO', 'CANCELADO'])) {
            sendJsonResponse(errorResponse("No se puede modificar una operación de un servicio en estado terminal ($estado_base)."), 403);
            exit;
        }
        
        // ESTADOS FINALES INTERMEDIOS: Solo si tiene permiso
        if (in_array($estado_base, ['FINALIZADO', 'CERRADO'])) {
            if (!$can_edit_closed_ops) {
                sendJsonResponse(errorResponse("No tienes permisos para editar operaciones en un servicio con estado $estado_base."), 403);
                exit;
            }
        }
    }
    $stmt_check_service->close();

    // 3.7. Verificar si la operación está FINALIZADA (por su propia fecha_fin)
    $stmt_check_op = $conn->prepare("SELECT fecha_fin FROM operaciones WHERE id = ?");
    $stmt_check_op->bind_param("i", $id);
    $stmt_check_op->execute();
    $res_check_op = $stmt_check_op->get_result();
    if ($row_op = $res_check_op->fetch_assoc()) {
        if (!empty($row_op['fecha_fin'])) {
            // La operación ya tiene fecha_fin. Verificar permiso (ya lo obtuvimos arriba)
            if (!$can_edit_closed_ops) {
                sendJsonResponse(errorResponse("La operación ya está finalizada y no tienes permisos para editar operaciones cerradas."), 403);
                exit;
            }
        }
    }
    $stmt_check_op->close();

    // 4. Construir UPDATE dinámico
    $updateFields = [];
    $params = [];
    $types = "";

    if (isset($data['descripcion'])) {
        $updateFields[] = "descripcion = ?";
        $params[] = $data['descripcion'];
        $types .= "s";
    }

    if (isset($data['fecha_inicio'])) {
        $updateFields[] = "fecha_inicio = ?";
        $params[] = $data['fecha_inicio'];
        $types .= "s";
    }

    // Lógica especial para FINALIZAR o Editar Fin
    if (isset($data['finalizar']) && $data['finalizar'] === true) {
        // Si al finalizar se envía una fecha_fin específica, usarla. Si no, usar NOW().
        if (isset($data['fecha_fin']) && !empty($data['fecha_fin'])) {
            $updateFields[] = "fecha_fin = ?";
            $params[] = $data['fecha_fin'];
            $types .= "s";
        } else {
            $updateFields[] = "fecha_fin = NOW()";
        }
    } elseif (array_key_exists('fecha_fin', $data)) {
        // Permitir resetear o editar fecha_fin si se envía un valor
        $updateFields[] = "fecha_fin = ?";
        $params[] = $data['fecha_fin'];
        $types .= "s";
    }

    if (isset($data['tecnico_responsable_id'])) {
        $updateFields[] = "tecnico_responsable_id = ?";
        $params[] = intval($data['tecnico_responsable_id']);
        $types .= "i";
    }

    if (isset($data['observaciones'])) {
        $updateFields[] = "observaciones = ?";
        $params[] = $data['observaciones'];
        $types .= "s";
    }

    if (empty($updateFields)) {
        sendJsonResponse(errorResponse('No hay campos para actualizar'), 400);
    }

    $sql = "UPDATE operaciones SET " . implode(", ", $updateFields) . " WHERE id = ?";
    $params[] = $id;
    $types .= "i";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Operación actualizada exitosamente'));
    } else {
        sendJsonResponse(errorResponse('Error al actualizar operación: ' . $conn->error), 500);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}
?>