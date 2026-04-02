<?php
/**
 * crear_factura_atomica.php
 * Emisión de Factura Comercial con Vínculo Multi-OT e Integridad Contable
 * Estándar Senior: Atomicidad Total (SQL Transaction)
 */
require_once '../login/auth_middleware.php';
require_once '../core/AccountingEngine.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);

    // Validaciones Básicas
    $cliente_id = $data['cliente_id'] ?? null;
    $servicios_ids = $data['servicios_ids'] ?? []; // Array de IDs de OT a facturar
    $metodo_pago = $data['metodo_pago'] ?? 'CONTADO';
    $prefijo = $data['prefijo'] ?? 'FEV';

    if (!$cliente_id || empty($servicios_ids)) {
        throw new Exception("Cliente y al menos un Servicio son requeridos para facturar.");
    }

    // 1. Validar Periodo Contable Abierto
    AccountingEngine::validatePeriod($conn, date('Y-m-d'));

    $conn->begin_transaction();

    // 2. Calcular Totales Agregados de los Snapshots
    $totalSubtotal = 0;
    $totalIVA = 0;
    $serviciosData = [];

    foreach ($servicios_ids as $sid) {
        $sqlS = "SELECT valor_snapshot, total_repuestos, total_mano_obra, estado_comercial_cache 
                FROM fac_control_servicios 
                WHERE servicio_id = ?";
        $stS = $conn->prepare($sqlS);
        $stS->bind_param("i", $sid);
        $stS->execute();
        $snap = $stS->get_result()->fetch_assoc();
        $stS->close();

        if (!$snap) {
            throw new Exception("No existe snapshot financiero para la OT #$sid. ¿Está legalizada?");
        }

        if ($snap['estado_comercial_cache'] !== 'CAUSADO') {
            throw new Exception("La OT #$sid no ha sido CAUSADA todavía. Debe confirmar la causación interna antes de generar la factura comercial.");
        }

        $serviciosData[$sid] = [
            'repuestos' => (float) $snap['total_repuestos'],
            'mano_obra' => (float) $snap['total_mano_obra'],
            'total' => (float) $snap['valor_snapshot']
        ];

        $totalSubtotal += (float) $snap['valor_snapshot'];
    }

    // TODO: En una implementación real, aquí se llamaría a la API de la DIAN
    // Para este MVP, generamos datos legales simulados
    $numeroFactura = "128"; // Simulado
    $cufe = bin2hex(random_bytes(20)); // Simulado
    $totalIVA = round($totalSubtotal * 0.19, 2);
    $totalNeto = $totalSubtotal + $totalIVA;

    // 3. Insertar Cabecera de Factura
    $sqlFactura = "INSERT INTO fac_facturas (cliente_id, prefijo, numero_factura, cufe, metodo_pago, fecha_emision, subtotal, iva, total_neto, saldo_actual, creado_por) 
                   VALUES (?, ?, ?, ?, ?, NOW(), ?, ?, ?, ?, ?)";
    $stF = $conn->prepare($sqlFactura);
    $stF->bind_param("issssddddi", $cliente_id, $prefijo, $numeroFactura, $cufe, $metodo_pago, $totalSubtotal, $totalIVA, $totalNeto, $totalNeto, $currentUser['id']);
    $stF->execute();
    $factura_id = $conn->insert_id;
    $stF->close();

    // 4. Vincular OTs y registrar distribución (Relación N:N)
    foreach ($serviciosData as $sid => $vals) {
        $itemIVA = round($vals['total'] * 0.19, 2);
        $itemSubtotal = $vals['total'] + $itemIVA;

        $sqlItem = "INSERT INTO fac_factura_items (factura_id, servicio_id, monto_repuestos, monto_mano_obra, base_iva, valor_iva, subtotal_item) 
                    VALUES (?, ?, ?, ?, ?, ?, ?)";
        $stI = $conn->prepare($sqlItem);
        $stI->bind_param("iiddddd", $factura_id, $sid, $vals['repuestos'], $vals['mano_obra'], $vals['total'], $itemIVA, $itemSubtotal);
        $stI->execute();
        $stI->close();
    }

    // 5. Generar Asiento Contable Oficial
    $referenciaAsiento = "$prefijo-$numeroFactura";
    $montosAsiento = [
        'TOTAL' => $totalNeto,
        'SUBTOTAL' => $totalSubtotal,
        'IMPUESTO' => $totalIVA
        // El motor ya sabe extraer REPUESTOS y MANO_OBRA si los pasamos (agregados)
    ];

    // Sumamos repuestos y MO de todas las OTs para el asiento global
    $aggRepuestos = array_sum(array_column($serviciosData, 'repuestos'));
    $aggMO = array_sum(array_column($serviciosData, 'mano_obra'));
    $montosAsiento['REPUESTOS'] = $aggRepuestos;
    $montosAsiento['MANO_OBRA'] = $aggMO;

    $asientoData = AccountingEngine::generateEntry($conn, 'GENERAR_FACTURA', $montosAsiento, $referenciaAsiento);

    // Persistir Asiento Oficial
    $sqlAsHeader = "INSERT INTO fin_asientos (referencia, fecha, evento_codigo, total_debito, total_credito, creado_por) VALUES (?, CURDATE(), 'GENERAR_FACTURA', ?, ?, ?)";
    $stAsH = $conn->prepare($sqlAsHeader);
    $stAsH->bind_param("sddi", $referenciaAsiento, $totalNeto, $totalNeto, $currentUser['id']);
    $stAsH->execute();
    $asiento_id = $conn->insert_id;
    $stAsH->close();

    foreach ($asientoData['detalles'] as $det) {
        $sqlDet = "INSERT INTO fin_asientos_detalle (asiento_id, puc_cuenta_id, tipo_movimiento, valor, descripcion) VALUES (?, ?, ?, ?, ?)";
        $stDet = $conn->prepare($sqlDet);
        $desc = "Factura $referenciaAsiento - " . $det['nombre'];
        $stDet->bind_param("iisds", $asiento_id, $det['cuenta_id'], $det['tipo'], $det['valor'], $desc);
        $stDet->execute();
        $stDet->close();
    }

    // 6. Automatización de Estados: Recalcular todas las OT afectadas
    foreach ($servicios_ids as $sid) {
        AccountingEngine::recalculateCommercialState($conn, $sid);
    }

    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => "Factura $prefijo-$numeroFactura generada exitosamente con atomicidad total.",
        'data' => [
            'factura_id' => $factura_id,
            'numero' => "$prefijo-$numeroFactura",
            'total' => $totalNeto
        ]
    ]);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
