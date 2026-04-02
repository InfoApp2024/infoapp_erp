<?php
/**
 * previsualizar_asiento.php
 * Genera una previsualización del asiento contable para un servicio legalizado
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);
require_once '../core/FactusService.php';
require_once '../core/AccountingEngine.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $servicio_id = $_GET['servicio_id'] ?? null;

    if (!$servicio_id) {
        throw new Exception("ID del servicio es requerido");
    }

    // 1. Obtener datos del snapshot y el cliente asociado (Trazabilidad Phase 3.7)
    $sqlSnap = "SELECT fc.valor_snapshot, fc.total_repuestos, fc.total_mano_obra, fc.ver_detalle_cotizacion, s.cliente_id, ae.actividad as nombre_servicio 
                FROM fac_control_servicios fc
                JOIN servicios s ON fc.servicio_id = s.id
                LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                WHERE fc.servicio_id = ?";
    $stmtS = $conn->prepare($sqlSnap);
    $stmtS->bind_param("i", $servicio_id);
    $stmtS->execute();
    $snap = $stmtS->get_result()->fetch_assoc();
    $stmtS->close();

    if (!$snap) {
        throw new Exception("No existe un snapshot financiero para este servicio. ¿Ya está legalizado?");
    }

    $cliente_id = $snap['cliente_id'];
    if (!$cliente_id) {
        throw new Exception("El servicio no tiene un cliente asociado para calcular impuestos.");
    }

    // 1.1 Obtener datos completos del Cliente para el Motor Tributario
    $stmtC = $conn->prepare("SELECT * FROM clientes WHERE id = ?");
    $stmtC->bind_param("i", $cliente_id);
    $stmtC->execute();
    $cliente = $stmtC->get_result()->fetch_assoc();
    $stmtC->close();

    // 2. Cargar Configuración Tributaria Dinámica Multi-Concepto (Auditoría OT 1288)
    $tax_engine_data = [
        'IVA' => FactusService::getTaxConfigs($conn, 'IVA'),
        'RETEFUENTE' => FactusService::getTaxConfigs($conn, 'RETEFUENTE'),
        'RETEICA' => []
    ];

    // Lógica ReteICA Jerárquica: Ciudad -> CIIU -> Global
    $ciudad_id = $cliente['ciudad_id'] ?? null;
    if ($ciudad_id) {
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA'); // Simple fetch for manual override
        // Nota: Si existiera cnf_tarifas_ica, se podríian mezclar, pero calculateWithholdings maneja bases y tarifas.
    } else {
        $ciiu = !empty($cliente['codigo_ciiu']) ? $cliente['codigo_ciiu'] : null;
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA', $ciiu);
        if (empty($tax_engine_data['RETEICA'])) {
            $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA', null);
        }
    }

    // Fallback de seguridad para ReteICA si sigue vacío
    if (empty($tax_engine_data['RETEICA'])) {
        $tax_engine_data['RETEICA'] = [
            [
                'nombre_impuesto' => 'ReteICA (Global)',
                'tarifa_x_mil' => 9.66,
                'base_minima_pesos' => 0
            ]
        ];
    }

    // 3. Cálculos de Impuestos y Retenciones
    $subtotal = (float) $snap['valor_snapshot'];
    $iva_pct = $tax_engine_data['IVA']['porcentaje'] ?? 19.00;
    $total_iva = round($subtotal * ($iva_pct / 100), 2);

    $retenciones_calc = FactusService::calculateWithholdings($subtotal, $cliente, $tax_engine_data);

    $extraDetalles = [];
    $total_retenciones = 0;

    // 3.1 Desglosar Repuestos Individualmente (Requerimiento Phase 3.9)
    $sqlRep = "SELECT i.name as item_nombre, sr.cantidad, sr.costo_unitario, sr.inventory_item_id 
               FROM servicio_repuestos sr
               JOIN inventory_items i ON sr.inventory_item_id = i.id
               WHERE sr.servicio_id = ?";
    $stRep = $conn->prepare($sqlRep);
    $stRep->bind_param("i", $servicio_id);
    $stRep->execute();
    $resRep = $stRep->get_result();

    $itemsRepuestosExtra = [];
    while ($rRep = $resRep->fetch_assoc()) {
        $montoRep = round($rRep['cantidad'] * $rRep['costo_unitario'], 2);
        if ($montoRep > 0) {
            $itemsRepuestosExtra[] = [
                'codigo' => '4135', // Cuenta de Ingresos por Mercancías (Repuestos)
                'nombre' => "Venta Repuesto: " . $rRep['item_nombre'],
                'tipo' => 'CREDITO',
                'valor' => $montoRep,
                'inventory_item_id' => $rRep['inventory_item_id']
            ];
        }
    }
    $stRep->close();

    // Inyectar repuestos al inicio de extraDetalles
    $extraDetalles = array_merge($extraDetalles, $itemsRepuestosExtra);

    // Mapeo de cuentas PUC para retenciones (Anticipos 1355)
    $puc_mapping = [
        '05' => ['codigo' => '135517', 'prefix' => 'ReteIVA'],
        '06' => ['codigo' => '135515', 'prefix' => 'ReteFuente'],
        '07' => ['codigo' => '135518', 'prefix' => 'ReteICA']
    ];

    foreach ($retenciones_calc as $ret) {
        $tipo_code = $ret['code'];
        $monto = (float) $ret['amount'];
        $total_retenciones += $monto;

        if (isset($puc_mapping[$tipo_code])) {
            $config = $puc_mapping[$tipo_code];
            $concept_name = $ret['name'] ?? $config['prefix'];

            $extraDetalles[] = [
                'codigo' => $config['codigo'],
                'nombre' => "{$concept_name} - " . ($cliente['nombre_completo'] ?? 'Cliente'),
                'tipo' => 'DEBITO', // Anticipo (Activo)
                'valor' => $monto
            ];
        }
    }

    $total_neto = ($subtotal + $total_iva) - $total_retenciones;

    $total_repuestos_sum = 0;
    foreach ($itemsRepuestosExtra as $r) {
        $total_repuestos_sum += $r['valor'];
    }

    $montos = [
        'TOTAL' => $total_neto,
        'SUBTOTAL' => $subtotal,
        'IMPUESTO' => $total_iva,
        'REPUESTOS' => 0.0, // Seteamos a 0 para que AccountingEngine no genere la línea genérica
        'REPUESTOS_TOTAL' => $total_repuestos_sum, // Nuevo: Para visualización en Cotización
        'MANO_OBRA' => (float) ($snap['total_mano_obra'] ?? 0)
    ];

    // 4. Validar Periodo Contable (Requerimiento Phase 3.9)
    $periodoAbierto = true;
    $mensajePeriodo = "";
    try {
        AccountingEngine::validatePeriod($conn, date('Y-m-d'));
    } catch (Exception $pe) {
        $periodoAbierto = false;
        $mensajePeriodo = $pe->getMessage();
    }

    // 4. Generar Asiento usando la Matriz de Causación + Detalles Extra Discriminados
    $asiento = AccountingEngine::generateEntry($conn, 'GENERAR_FACTURA', $montos, "PREV-OT-$servicio_id", $extraDetalles);

    // Post-procesar nombres de cuentas para mayor claridad (Requerimiento 3.7)
    $nombre_real = $snap['nombre_servicio'] ?? 'Servicio';
    foreach ($asiento['detalles'] as &$det) {
        if (strpos($det['nombre'], 'Ingresos') !== false || strpos($det['codigo'], '41') === 0) {
            $det['nombre'] .= " ($nombre_real)";
        }
        if (strpos($det['nombre'], 'Cuentas por Cobrar') !== false || strpos($det['codigo'], '1305') === 0) {
            $det['nombre'] .= " - " . ($cliente['nombre_completo'] ?? 'Cliente');
        }
    }

    sendJsonResponse([
        'success' => true,
        'data' => [
            'asiento' => $asiento,
            'periodo_abierto' => $periodoAbierto,
            'ver_detalle_cotizacion' => (bool) ($snap['ver_detalle_cotizacion'] ?? true),
            'fecha_actual' => date('Y-m-d'),
            'montos_base' => $montos,
            'tax_engine' => [
                'ciudad_id' => $ciudad_id,
                'regimen' => $cliente['regimen_tributario'],
                'responsabilidad' => $cliente['responsabilidad_fiscal_id']
            ]
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
