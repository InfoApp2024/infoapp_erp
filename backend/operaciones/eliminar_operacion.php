<?php
// backend/operaciones/eliminar_operacion.php
require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación JWT
    $currentUser = requireAuth();

    // 2. Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // 3. Obtener ID (puede venir por DELETE params o POST body)
    $id = 0;
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        if (isset($_GET['id'])) {
            $id = intval($_GET['id']);
        }
    } else {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);
        if (isset($data['id'])) {
            $id = intval($data['id']);
        }
    }

    if ($id <= 0) {
        sendJsonResponse(errorResponse('ID de operación inválido'), 400);
    }

    // Conexión a BD
    require '../conexion.php';

    $conn->begin_transaction();

    try {
        // 3.4 Verificar que el servicio padre no estÃ© en un estado final protegido
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
            $estado_base = $row_service['estado_base_codigo'];
            if (in_array($estado_base, ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'])) {
                sendJsonResponse(errorResponse("No se puede eliminar una operaciÃ³n de un servicio en estado final ($estado_base)."), 403);
                exit;
            }
        }
        $stmt_check_service->close();

        // 3.6. Verificar si la operación está FINALIZADA y si el usuario tiene permiso para eliminarla
        $stmt_check_op_fin = $conn->prepare("SELECT fecha_fin FROM operaciones WHERE id = ?");
        $stmt_check_op_fin->bind_param("i", $id);
        $stmt_check_op_fin->execute();
        $res_check_op_fin = $stmt_check_op_fin->get_result();
        if ($row_op_fin = $res_check_op_fin->fetch_assoc()) {
            if (!empty($row_op_fin['fecha_fin'])) {
                // La operación está cerrada. Verificar permiso del usuario.
                $stmt_user_perm = $conn->prepare("SELECT can_edit_closed_ops FROM usuarios WHERE id = ?");
                $stmt_user_perm->bind_param("i", $currentUser['id']);
                $stmt_user_perm->execute();
                $res_user_perm = $stmt_user_perm->get_result();
                $user_perm = $res_user_perm->fetch_assoc();
                $can_edit = ($user_perm && (int)$user_perm['can_edit_closed_ops'] === 1);
                $stmt_user_perm->close();

                if (!$can_edit) {
                    sendJsonResponse(errorResponse("No se puede eliminar una operación ya finalizada sin los permisos correspondientes."), 403);
                    exit;
                }
            }
        }
        $stmt_check_op_fin->close();
        // 3.5 Verificar que no sea la Operación Maestra
        $stmt_check = $conn->prepare("SELECT is_master, servicio_id FROM operaciones WHERE id = ?");
        $stmt_check->bind_param("i", $id);
        $stmt_check->execute();
        $res_check = $stmt_check->get_result();
        $op_data = $res_check->fetch_assoc();
        $stmt_check->close();

        if (!$op_data) {
            throw new Exception("Operación no encontrada");
        }

        if ((int) $op_data['is_master'] === 1) {
            sendJsonResponse(errorResponse('No se puede eliminar la Operación Maestra (Alistamiento/General).'), 403);
            exit;
        }

        $servicioId = (int) $op_data['servicio_id'];

        // 4. RESTAURAR STOCK DE REPUESTOS ASOCIADOS
        // Buscamos los repuestos vinculados a esta operación para devolver stock antes de borrar
        $stmt_rep = $conn->prepare("SELECT inventory_item_id, cantidad, costo_unitario FROM servicio_repuestos WHERE operacion_id = ?");
        $stmt_rep->bind_param("i", $id);
        $stmt_rep->execute();
        $res_rep = $stmt_rep->get_result();

        while ($rep = $res_rep->fetch_assoc()) {
            $itemId = (int) $rep['inventory_item_id'];
            $cantidad = (float) $rep['cantidad'];
            $costo = (float) $rep['costo_unitario'];

            // Devolver stock
            $conn->query("UPDATE inventory_items SET current_stock = current_stock + $cantidad WHERE id = $itemId");

            // Registrar movimiento de retorno
            $notes = "Retorno por eliminación de operación #$id";
            $stmt_mov = $conn->prepare("
                INSERT INTO inventory_movements (
                    inventory_item_id, movement_type, movement_reason, quantity, 
                    previous_stock, new_stock, unit_cost, reference_type, 
                    reference_id, notes, created_by, created_at
                ) 
                SELECT ?, 'entrada', 'devolucion', ?, current_stock - ?, current_stock, ?, 'service', ?, ?, ?, NOW()
                FROM inventory_items WHERE id = ?
            ");
            $stmt_mov->bind_param("idddisii", $itemId, $cantidad, $cantidad, $costo, $servicioId, $notes, $currentUser['id'], $itemId);
            $stmt_mov->execute();
            $stmt_mov->close();
        }
        $stmt_rep->close();

        // Eliminar los registros de repuestos de esta operación (para evitar que el Trigger los mueva a la Maestra)
        $conn->query("DELETE FROM servicio_repuestos WHERE operacion_id = $id");

        // 5. Eliminar operación
        $sql = "DELETE FROM operaciones WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);

        if (!$stmt->execute()) {
            throw new Exception("Error al eliminar operación: " . $stmt->error);
        }

        $conn->commit();
        sendJsonResponse(successResponse(null, 'Operación eliminada exitosamente y stock restaurado.'));

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}
?>