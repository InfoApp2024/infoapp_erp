<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio_repuestos/eliminar_todos_repuestos_servicio.php', 'bulk_delete_inventory');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Input
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        sendJsonResponse(errorResponse('JSON inválido'), 400);
    }

    $servicioId = isset($input['servicio_id']) ? (int) $input['servicio_id'] : 0;
    $razon = $input['razon'] ?? 'Eliminación masiva por anulación de servicio';
    $usuarioElimina = $currentUser['id'];

    if ($servicioId <= 0) {
        sendJsonResponse(errorResponse('ID de servicio inválido'), 400);
    }

    require '../conexion.php';

    // ✅ PASO 4.5: Control de Estados y Permisos (Seguridad)
    $sqlState = "SELECT eb.nombre as estado_base_nombre, eb.codigo as estado_base_codigo, eb.permite_edicion
                FROM servicios s
                JOIN estados_proceso ep ON s.estado = ep.id
                JOIN estados_base eb ON ep.estado_base_codigo = eb.codigo
                WHERE s.id = ? LIMIT 1";
    $stmtState = $conn->prepare($sqlState);
    $stmtState->bind_param("i", $servicioId);
    $stmtState->execute();
    $resState = $stmtState->get_result();
    $baseInfo = $resState->fetch_assoc();
    $stmtState->close();

    if ($baseInfo && (int)$baseInfo['permite_edicion'] === 0) {
        // Verificar bypass
        $sqlPerm = "SELECT can_edit_closed_ops FROM usuarios WHERE id = ? LIMIT 1";
        $stmtPerm = $conn->prepare($sqlPerm);
        $stmtPerm->bind_param("i", $currentUser['id']);
        $stmtPerm->execute();
        $resPerm = $stmtPerm->get_result();
        $canEdit = false;
        if ($rowPerm = $resPerm->fetch_assoc()) {
            $canEdit = ((int)$rowPerm['can_edit_closed_ops'] === 1);
        }
        $stmtPerm->close();

        $isTerminal = in_array($baseInfo['estado_base_codigo'], ['LEGALIZADO', 'CANCELADO']);

        if ($isTerminal || !$canEdit) {
            sendJsonResponse(errorResponse("No se pueden eliminar los repuestos. El servicio está en estado '{$baseInfo['estado_base_nombre']}'."), 403);
        }
    }

    $conn->autocommit(false);

    try {
        // PASO 5: Verificar servicio y obtener repuestos
        $stmtGet = $conn->prepare("
            SELECT 
                sr.id,
                sr.inventory_item_id,
                sr.cantidad,
                sr.costo_unitario,
                i.name as item_nombre,
                i.current_stock
            FROM servicio_repuestos sr
            INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
            WHERE sr.servicio_id = ?
        ");
        $stmtGet->bind_param("i", $servicioId);
        $stmtGet->execute();
        $result = $stmtGet->get_result();

        $itemsProcesados = [];
        $idsParaEliminar = [];

        while ($row = $result->fetch_assoc()) {
            $repuestoId = $row['id'];
            $itemId = $row['inventory_item_id'];
            $cantidad = $row['cantidad'];
            $stockActual = $row['current_stock'];

            // PASO 6: Restaurar stock
            $stmtUpdateStock = $conn->prepare("UPDATE inventory_items SET current_stock = current_stock + ? WHERE id = ?");
            $stmtUpdateStock->bind_param("di", $cantidad, $itemId);
            if (!$stmtUpdateStock->execute()) {
                throw new Exception("Error restaurando stock para item $itemId");
            }
            $stmtUpdateStock->close();

            // PASO 7: Registrar movimiento inventario
            $stockFinal = $stockActual + $cantidad;
            $stmtMov = $conn->prepare("
                INSERT INTO inventory_movements (inventory_item_id, movement_type, movement_reason, quantity, previous_stock, new_stock, unit_cost, reference_type, reference_id, notes, created_by, created_at)
                VALUES (?, 'entrada', 'devolucion', ?, ?, ?, ?, 'service', ?, ?, ?, NOW())
            ");
            $costo = $row['costo_unitario'];
            $notes = "Devolución masiva servicio #$servicioId - $razon";
            $stmtMov->bind_param("iddddisi", $itemId, $cantidad, $stockActual, $stockFinal, $costo, $servicioId, $notes, $usuarioElimina);
            $stmtMov->execute();
            $stmtMov->close();

            $itemsProcesados[] = $row['item_nombre'];
            $idsParaEliminar[] = $repuestoId;
        }
        $stmtGet->close();

        if (empty($idsParaEliminar)) {
            // No había repuestos, igual es success
            $conn->commit();
            sendJsonResponse(successResponse(null, 'No había repuestos para eliminar'));
        }

        // PASO 8: Eliminar filas
        // Usar implode seguros ya que son ints
        $idsStr = implode(',', array_map('intval', $idsParaEliminar));
        $conn->query("DELETE FROM servicio_repuestos WHERE id IN ($idsStr)");

        // PASO 9: Resetear flag servicio
        $conn->query("UPDATE servicios SET suministraron_repuestos = 0 WHERE id = $servicioId");

        $conn->commit();

        sendJsonResponse(successResponse([
            'items_eliminados' => count($itemsProcesados),
            'nombres' => $itemsProcesados
        ], 'Repuestos eliminados y stock restaurado exitosamente'));

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    if (isset($conn) && $conn->errno)
        $conn->close();
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}
?>