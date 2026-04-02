<?php
/**
 * cambiar_estado_financiero.php
 * Cambia el estado financiero de un servicio (o grupo de servicios de una factura)
 * y reinicia el cronómetro SLA.
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);

    $servicio_id = $data['servicio_id'] ?? null;
    $factura_id = $data['factura_id'] ?? null;
    $nuevo_estado_id = $data['nuevo_estado_id'] ?? null;
    $observacion = $data['observacion'] ?? 'Cambio manual de estado financiero';

    if (!$nuevo_estado_id) {
        throw new Exception("El nuevo_estado_id es requerido.");
    }

    if (!$servicio_id && !$factura_id) {
        throw new Exception("Se requiere especificar un servicio_id o factura_id.");
    }

    $conn->begin_transaction();

    // Validar el estado destino
    $stmtE = $conn->prepare("SELECT id, nombre_estado FROM estados_proceso WHERE id = ? AND modulo = 'FINANCIERO'");
    $stmtE->bind_param("i", $nuevo_estado_id);
    $stmtE->execute();
    $estResult = $stmtE->get_result()->fetch_assoc();
    $stmtE->close();

    if (!$estResult) {
        throw new Exception("El estado financiero destino no es válido.");
    }

    $serviciosAfectados = [];

    if ($servicio_id) {
        // Encontrar estado anterior para log
        $stmtA = $conn->prepare("SELECT estado_financiero_id FROM servicios WHERE id = ?");
        $stmtA->bind_param("i", $servicio_id);
        $stmtA->execute();
        $antInfo = $stmtA->get_result()->fetch_assoc();
        $stmtA->close();

        $serviciosAfectados[] = [
            'id' => $servicio_id, 
            'ant_id' => $antInfo['estado_financiero_id'] ?? null
        ];

        // Ejecutar actualización individual
        $stmtU = $conn->prepare("UPDATE servicios SET estado_financiero_id = ?, estado_fin_fecha_inicio = NOW() WHERE id = ?");
        $stmtU->bind_param("ii", $nuevo_estado_id, $servicio_id);
        $stmtU->execute();
        $stmtU->close();

    } else if ($factura_id) {
        // Encontrar servicios asociados a la factura
        $stmtA = $conn->prepare("
            SELECT s.id, s.estado_financiero_id 
            FROM servicios s 
            JOIN fac_factura_items fi ON fi.servicio_id = s.id 
            WHERE fi.factura_id = ?
        ");
        $stmtA->bind_param("i", $factura_id);
        $stmtA->execute();
        $resA = $stmtA->get_result();
        while ($row = $resA->fetch_assoc()) {
            $serviciosAfectados[] = [
                'id' => $row['id'], 
                'ant_id' => $row['estado_financiero_id']
            ];
        }
        $stmtA->close();

        // Ejecutar actualización masiva
        $stmtU = $conn->prepare("
            UPDATE servicios s 
            JOIN fac_factura_items fi ON fi.servicio_id = s.id 
            SET s.estado_financiero_id = ?, s.estado_fin_fecha_inicio = NOW() 
            WHERE fi.factura_id = ?
        ");
        $stmtU->bind_param("ii", $nuevo_estado_id, $factura_id);
        $stmtU->execute();
        $stmtU->close();
    }

    // Insertar logs (Trazabilidad)
    $stmtL = $conn->prepare("
        INSERT INTO estados_servicios_log (servicio_id, estado_anterior_id, estado_nuevo_id, modulo, usuario_id, observacion) 
        VALUES (?, ?, ?, 'FINANCIERO', ?, ?)
    ");
    foreach ($serviciosAfectados as $sv) {
        $stmtL->bind_param("iiiis", $sv['id'], $sv['ant_id'], $nuevo_estado_id, $currentUser['id'], $observacion);
        $stmtL->execute();
    }
    $stmtL->close();

    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => 'Estado financiero actualizado correctamente a ' . $estResult['nombre_estado'],
        'servicios_afectados' => count($serviciosAfectados)
    ]);

} catch (Exception $e) {
    if (isset($conn)) $conn->rollback();
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
