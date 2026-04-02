<?php
/**
 * obtener_transiciones_financieras.php
 * Retorna los estados financieros permitidos (transiciones) desde el estado actual.
 */
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, GET, OPTIONS");
header("Content-Type: application/json; charset=utf-8");

try {
    require '../conexion.php';
    require '../login/auth_middleware.php';
    // requireAuth(); // Opcional dependiendo de la seguridad requerida

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) $input = $_GET;

    $servicio_id = $input['servicio_id'] ?? null;
    $factura_id = $input['factura_id'] ?? null;

    if (!$servicio_id && !$factura_id) {
        throw new Exception("Se requiere servicio_id o factura_id.");
    }

    $estado_actual_id = null;

    if ($servicio_id) {
        $stmt = $conn->prepare("SELECT estado_financiero_id FROM servicios WHERE id = ?");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $estado_actual_id = $res['estado_financiero_id'] ?? null;
        $stmt->close();
    } else {
        // Para facturas, tomamos el estado de uno de sus servicios vinculados
        $stmt = $conn->prepare("
            SELECT s.estado_financiero_id 
            FROM servicios s 
            JOIN fac_factura_items fi ON fi.servicio_id = s.id 
            WHERE fi.factura_id = ? 
            LIMIT 1
        ");
        $stmt->bind_param("i", $factura_id);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $estado_actual_id = $res['estado_financiero_id'] ?? null;
        $stmt->close();
    }

    // Si no tiene estado (NULL), buscamos el estado inicial del módulo FINANCIERO
    if (!$estado_actual_id) {
        $resIni = $conn->query("SELECT id FROM estados_proceso WHERE modulo = 'FINANCIERO' ORDER BY orden ASC LIMIT 1");
        $rowIni = $resIni->fetch_assoc();
        $estado_actual_id = $rowIni['id'] ?? null;
    }

    $transiciones = [];

    if ($estado_actual_id) {
        // 1. Incluir el estado actual (siempre debe ser una opción visible)
        $stmtActual = $conn->prepare("SELECT id, TRIM(nombre_estado) as nombre_estado, TRIM(color) as color, TRIM(estado_base_codigo) as estado_base_codigo FROM estados_proceso WHERE id = ?");
        $stmtActual->bind_param("i", $estado_actual_id);
        $stmtActual->execute();
        $itemActual = $stmtActual->get_result()->fetch_assoc();
        if ($itemActual) {
            $itemActual['es_actual'] = true;
            $transiciones[] = $itemActual;
        }
        $stmtActual->close();

        // 2. Buscar transiciones permitidas
        $stmtT = $conn->prepare("
            SELECT ep.id, TRIM(ep.nombre_estado) as nombre_estado, TRIM(ep.color) as color, TRIM(ep.estado_base_codigo) as estado_base_codigo, t.nombre as nombre_transicion
            FROM transiciones_estado t
            JOIN estados_proceso ep ON t.estado_destino_id = ep.id
            WHERE t.estado_origen_id = ? AND t.modulo = 'FINANCIERO'
            ORDER BY ep.orden ASC
        ");
        $stmtT->bind_param("i", $estado_actual_id);
        $stmtT->execute();
        $resT = $stmtT->get_result();
        while ($row = $resT->fetch_assoc()) {
            $row['es_actual'] = false;
            $transiciones[] = $row;
        }
        $stmtT->close();
    }

    echo json_encode([
        'success' => true,
        'data' => $transiciones,
        'estado_actual_id' => $estado_actual_id
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
