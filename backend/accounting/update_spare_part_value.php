<?php
/**
 * update_spare_part_value.php
 * Actualiza el valor unitario de un repuesto específico y recalcula el total del servicio con auditoría.
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);
    $servicio_id = $data['servicio_id'] ?? null;
    $inventory_item_id = $data['inventory_item_id'] ?? null;
    $nuevo_valor_total = $data['nuevo_valor_total'] ?? null; // Valor TOTAL del ítem (cantidad × unitario)
    $motivo = $data['motivo'] ?? null;

    if (!$servicio_id || !$inventory_item_id || $nuevo_valor_total === null || !$motivo) {
        throw new Exception("Datos incompletos para el ajuste de repuesto.");
    }

    // 1. Obtener datos del repuesto específico y nombre del item
    $sqlItem = "SELECT sr.cantidad, sr.costo_unitario, i.name as item_nombre 
                FROM servicio_repuestos sr
                JOIN inventory_items i ON sr.inventory_item_id = i.id
                WHERE sr.servicio_id = ? AND sr.inventory_item_id = ?";
    $stmtI = $conn->prepare($sqlItem);
    $stmtI->bind_param("ii", $servicio_id, $inventory_item_id);
    $stmtI->execute();
    $itemData = $stmtI->get_result()->fetch_assoc();
    $stmtI->close();

    if (!$itemData) {
        throw new Exception("El repuesto no está asociado a este servicio.");
    }

    $valor_unitario_anterior = (float) $itemData['costo_unitario'];
    $item_nombre = $itemData['item_nombre'];
    $cantidad = (float) $itemData['cantidad'];

    if ($cantidad <= 0) {
        throw new Exception("La cantidad del repuesto es inválida.");
    }

    // Calcular el nuevo costo unitario dividiendo el total ingresado por la cantidad
    // El usuario siempre ingresa el VALOR TOTAL del ítem, no el unitario.
    $nuevo_valor_unitario = $nuevo_valor_total / $cantidad;

    // 2. Verificar estado del snapshot
    $stmtS = $conn->prepare("SELECT estado_comercial_cache, total_repuestos, total_mano_obra FROM fac_control_servicios WHERE servicio_id = ?");
    $stmtS->bind_param("i", $servicio_id);
    $stmtS->execute();
    $snap = $stmtS->get_result()->fetch_assoc();
    $stmtS->close();

    if (!$snap) {
        throw new Exception("No existe snapshot para este servicio.");
    }

    if ($snap['estado_comercial_cache'] !== 'NO_FACTURADO' && $snap['estado_comercial_cache'] !== 'PENDIENTE') {
        throw new Exception("No se puede editar un servicio ya procesado.");
    }

    $conn->begin_transaction();

    // 3. Actualizar el valor unitario en la tabla de repuestos del servicio
    $stmtU = $conn->prepare("UPDATE servicio_repuestos SET costo_unitario = ? WHERE servicio_id = ? AND inventory_item_id = ?");
    $stmtU->bind_param("dii", $nuevo_valor_unitario, $servicio_id, $inventory_item_id);
    $stmtU->execute();
    $stmtU->close();

    // 4. Recalcular el total_repuestos del servicio
    $sqlSum = "SELECT SUM(cantidad * costo_unitario) as nuevo_total FROM servicio_repuestos WHERE servicio_id = ?";
    $stmtSum = $conn->prepare($sqlSum);
    $stmtSum->bind_param("i", $servicio_id);
    $stmtSum->execute();
    $resSum = $stmtSum->get_result()->fetch_assoc();
    $nuevo_total_repuestos = (float) ($resSum['nuevo_total'] ?? 0);
    $stmtSum->close();

    // 5. Registrar Auditoría detallada
    $campoAuditoria = "REPUESTOS ($item_nombre)";
    $valor_tot_anterior_item = $cantidad * $valor_unitario_anterior;
    $valor_tot_nuevo_item = $cantidad * $nuevo_valor_unitario;

    $stmtA = $conn->prepare("INSERT INTO fac_snapshot_ajustes (servicio_id, usuario_id, campo, valor_anterior, valor_nuevo, motivo, fecha) VALUES (?, ?, ?, ?, ?, ?, NOW())");
    $stmtA->bind_param("iisdds", $servicio_id, $currentUser['id'], $campoAuditoria, $valor_tot_anterior_item, $valor_tot_nuevo_item, $motivo);
    $stmtA->execute();
    $stmtA->close();

    // 6. Actualizar el Snapshot general
    $nuevo_valor_snapshot = $nuevo_total_repuestos + (float) $snap['total_mano_obra'];
    $stmtSnap = $conn->prepare("UPDATE fac_control_servicios SET total_repuestos = ?, valor_snapshot = ? WHERE servicio_id = ?");
    $stmtSnap->bind_param("ddi", $nuevo_total_repuestos, $nuevo_valor_snapshot, $servicio_id);
    $stmtSnap->execute();
    $stmtSnap->close();

    // 7. Registrar Nota de Auditoría
    $mensajeLog = "AJUSTE INDIVIDUAL REPUESTO [$item_nombre]: Unitario " . number_format($valor_unitario_anterior, 2) . " -> " . number_format($nuevo_valor_unitario, 2) . ". Total ítem: " . number_format($valor_tot_nuevo_item, 2) . ". Motivo: $motivo";
    $stmtL = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id) VALUES (?, ?, CURDATE(), CURTIME(), ?, ?)");
    $stmtL->bind_param("issi", $servicio_id, $mensajeLog, $currentUser['usuario'], $currentUser['id']);
    $stmtL->execute();
    $stmtL->close();

    $conn->commit();

    echo json_encode(['success' => true, 'message' => 'Repuesto actualizado y total recalculado.']);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
} finally {
    if (isset($conn))
        $conn->close();
}
