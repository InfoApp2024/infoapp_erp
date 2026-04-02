<?php
/**
 * update_snapshot_values.php
 * Actualiza valores de MO o Repuestos en fac_control_servicios con auditoría obligatoria.
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);
    $servicio_id = $data['servicio_id'] ?? null;
    $campo = $data['campo'] ?? null; // 'MANO_OBRA' or 'REPUESTOS'
    $nuevo_valor = $data['nuevo_valor'] ?? null;
    $motivo = $data['motivo'] ?? null;

    if (!$servicio_id || !$campo || $nuevo_valor === null || !$motivo) {
        throw new Exception("Datos incompletos para el ajuste.");
    }

    if (!in_array($campo, ['MANO_OBRA', 'REPUESTOS'])) {
        throw new Exception("Campo no válido para ajuste.");
    }

    // 1. Verificar estado actual
    $stmtS = $conn->prepare("SELECT total_mano_obra, total_repuestos, estado_comercial_cache FROM fac_control_servicios WHERE servicio_id = ?");
    $stmtS->bind_param("i", $servicio_id);
    $stmtS->execute();
    $snap = $stmtS->get_result()->fetch_assoc();
    $stmtS->close();

    if (!$snap) {
        throw new Exception("No existe un snapshot para este servicio.");
    }

    if ($snap['estado_comercial_cache'] !== 'NO_FACTURADO' && $snap['estado_comercial_cache'] !== 'PENDIENTE') {
        throw new Exception("No se puede editar un servicio que ya ha sido causado o facturado.");
    }

    $valor_anterior = ($campo === 'MANO_OBRA') ? $snap['total_mano_obra'] : $snap['total_repuestos'];

    $conn->begin_transaction();

    // 2. Registrar Auditoría
    $stmtA = $conn->prepare("INSERT INTO fac_snapshot_ajustes (servicio_id, usuario_id, campo, valor_anterior, valor_nuevo, motivo, fecha) VALUES (?, ?, ?, ?, ?, ?, NOW())");
    $stmtA->bind_param("iisdds", $servicio_id, $currentUser['id'], $campo, $valor_anterior, $nuevo_valor, $motivo);
    $stmtA->execute();
    $stmtA->close();

    // 3. Actualizar Snapshot
    $sqlUpd = ($campo === 'MANO_OBRA')
        ? "UPDATE fac_control_servicios SET total_mano_obra = ?, valor_snapshot = ? + total_repuestos WHERE servicio_id = ?"
        : "UPDATE fac_control_servicios SET total_repuestos = ?, valor_snapshot = ? + total_mano_obra WHERE servicio_id = ?";

    $stmtU = $conn->prepare($sqlUpd);
    $stmtU->bind_param("ddi", $nuevo_valor, $nuevo_valor, $servicio_id);
    $stmtU->execute();
    $stmtU->close();

    // 4. Registrar Nota en el Servicio para visibilidad manual
    $mensajeLog = "AJUSTE FINANCIERO [$campo]: De " . number_format($valor_anterior, 2) . " a " . number_format($nuevo_valor, 2) . ". Motivo: $motivo";
    $stmtL = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id) VALUES (?, ?, CURDATE(), CURTIME(), ?, ?)");
    $stmtL->bind_param("issi", $servicio_id, $mensajeLog, $currentUser['usuario'], $currentUser['id']);
    $stmtL->execute();
    $stmtL->close();

    $conn->commit();

    echo json_encode(['success' => true, 'message' => 'Ajuste guardado con éxito y auditado.']);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
