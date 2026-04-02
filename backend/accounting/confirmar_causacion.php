<?php
/**
 * confirmar_causacion.php
 * Persiste el asiento contable en el log (Fase 2)
 */
require_once '../login/auth_middleware.php';
require_once '../core/AccountingEngine.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);
    $servicio_id = $data['servicio_id'] ?? null;

    if (!$servicio_id) {
        throw new Exception("ID del servicio es requerido");
    }

    // 1. Validar Periodo
    AccountingEngine::validatePeriod($conn, date('Y-m-d'));

    // 2. Obtener Snapshot
    $sqlSnap = "SELECT valor_snapshot, total_repuestos, total_mano_obra FROM fac_control_servicios WHERE servicio_id = ?";
    $stmtS = $conn->prepare($sqlSnap);
    $stmtS->bind_param("i", $servicio_id);
    $stmtS->execute();
    $snap = $stmtS->get_result()->fetch_assoc();
    $stmtS->close();

    if (!$snap) {
        throw new Exception("Snapshot no encontrado");
    }

    $total = (float) $snap['valor_snapshot'];
    $repuestos = (float) ($snap['total_repuestos'] ?? 0);
    $manoObra = (float) ($snap['total_mano_obra'] ?? 0);

    // 3. Obtener Repuestos Detallados (Phase 3.9)
    $sqlRep = "SELECT i.name as item_nombre, sr.cantidad, sr.costo_unitario 
               FROM servicio_repuestos sr
               JOIN inventory_items i ON sr.inventory_item_id = i.id
               WHERE sr.servicio_id = ?";
    $stRep = $conn->prepare($sqlRep);
    $stRep->bind_param("i", $servicio_id);
    $stRep->execute();
    $resRep = $stRep->get_result();

    $extraDetalles = [];
    while ($rRep = $resRep->fetch_assoc()) {
        $montoRep = round($rRep['cantidad'] * $rRep['costo_unitario'], 2);
        if ($montoRep > 0) {
            $extraDetalles[] = [
                'codigo' => '4135',
                'nombre' => "Venta Repuesto: " . $rRep['item_nombre'],
                'tipo' => 'CREDITO',
                'valor' => $montoRep
            ];
        }
    }
    $stRep->close();

    $montos = [
        'TOTAL' => $total,
        'SUBTOTAL' => $total,
        'IMPUESTO' => 0,
        'REPUESTOS' => 0.0, // Detallado vía extraDetalles
        'MANO_OBRA' => $manoObra
    ];

    // 4. Generar Asiento
    $asiento = AccountingEngine::generateEntry($conn, 'GENERAR_FACTURA', $montos, "OT-$servicio_id", $extraDetalles);

    // 4. Persistir en Log (Transaccional)
    $conn->begin_transaction();

    foreach ($asiento['detalles'] as $det) {
        $sqlLog = "INSERT INTO fin_asientos_log (servicio_id, p_cuenta, tipo, valor, referencia, creado_por) 
                   VALUES (?, ?, ?, ?, ?, ?)";
        $stmtL = $conn->prepare($sqlLog);
        $referencia = "CAUSACION-OT-$servicio_id";
        $stmtL->bind_param("issdsi", $servicio_id, $det['codigo'], $det['tipo'], $det['valor'], $referencia, $currentUser['id']);
        $stmtL->execute();
    }

    // Actualizar estado comercial a 'CAUSADO' (Audit only for Phase 2)
    $sqlUpd = "UPDATE fac_control_servicios SET estado_comercial_cache = 'CAUSADO' WHERE servicio_id = ?";
    $stmtU = $conn->prepare($sqlUpd);
    $stmtU->bind_param("i", $servicio_id);
    $stmtU->execute();

    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => "Asiento contable registrado en log exitosamente"
    ]);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
