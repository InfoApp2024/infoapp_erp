<?php
/**
 * create_invoice.php
 * Controlador de Facturación Electrónica Atómica (Standard Senior)
 * Integra Factus API + Contabilidad Interna + Transaccionalidad SQL
 */

define('AUTH_REQUIRED', true); // Requerido para FactusService/Config
require_once '../login/auth_middleware.php';
require_once '../core/FactusService.php';
require_once '../core/AccountingEngine.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);

    $cliente_id = $data['cliente_id'] ?? null;
    $servicios_ids = $data['servicios_ids'] ?? [];
    $metodo_pago = $data['metodo_pago'] ?? 1; // 1: Contado, 2: Crédito (Estándar Factus)
    $observaciones = trim($data['observaciones'] ?? '');

    if (!$cliente_id || empty($servicios_ids)) {
        throw new Exception("Datos insuficientes: Cliente y OTs son requeridos.");
    }

    // 1. Validar Periodo Contable
    AccountingEngine::validatePeriod($conn, date('Y-m-d'));

    // [REGLA DE ORO]: Validar si alguna OT ya fue facturada exitosamente
    foreach ($servicios_ids as $sid) {
        $sqlCheck = "SELECT f.prefijo, f.numero_factura 
                     FROM fac_facturas f 
                     WHERE f.servicio_id = ? AND (f.estado = 'Exitosa' OR f.estado IS NULL)"; // Consideramos NULL como exitosa inicial
        $stCheck = $conn->prepare($sqlCheck);
        $stCheck->bind_param("i", $sid);
        $stCheck->execute();
        $existingBill = $stCheck->get_result()->fetch_assoc();
        $stCheck->close();

        if ($existingBill) {
            $ref = $existingBill['prefijo'] . "-" . $existingBill['numero_factura'];
            throw new Exception("La Orden de Trabajo (OT) #$sid ya cuenta con una factura legal emitida ($ref). Evitando duplicación legal.");
        }
    }

    // 2. Obtener datos del Cliente (Full Legal)
    $stmtC = $conn->prepare("SELECT * FROM clientes WHERE id = ?");
    $stmtC->bind_param("i", $cliente_id);
    $stmtC->execute();
    $cliente = $stmtC->get_result()->fetch_assoc();
    $stmtC->close();

    if (!$cliente)
        throw new Exception("Cliente no encontrado en la base de datos.");

    // 2.1 Carga Dinámica Multi-Concepto (Auditoría OT 1288)
    $tax_engine_data = [
        'IVA' => FactusService::getTaxConfigs($conn, 'IVA'),
        'RETEFUENTE' => FactusService::getTaxConfigs($conn, 'RETEFUENTE'),
        'RETEICA' => []
    ];

    // Lógica ReteICA Jerárquica: Ciudad -> CIIU -> Global
    $ciudad_id = $cliente['ciudad_id'] ?? null;
    if ($ciudad_id) {
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA');
    } else {
        $ciiu = !empty($cliente['codigo_ciiu']) ? $cliente['codigo_ciiu'] : null;
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA', $ciiu);
        if (empty($tax_engine_data['RETEICA'])) {
            $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA', null);
        }
    }

    // Fallback de seguridad para ReteICA (0.966%)
    if (empty($tax_engine_data['RETEICA'])) {
        $tax_engine_data['RETEICA'] = [
            [
                'nombre_impuesto' => 'ReteICA (Global)',
                'tarifa_x_mil' => 9.66,
                'base_minima_pesos' => 0
            ]
        ];
    }

    // 3. Obtener Snapshots de OTs y validar
    $serviciosData = [];
    foreach ($servicios_ids as $sid) {
        $sqlS = "SELECT fc.*, s.o_servicio as numero_orden, ae.actividad as nombre_servicio 
                FROM fac_control_servicios fc
                JOIN servicios s ON fc.servicio_id = s.id
                LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                WHERE fc.servicio_id = ?";
        $stS = $conn->prepare($sqlS);
        $stS->bind_param("i", $sid);
        $stS->execute();
        $snap = $stS->get_result()->fetch_assoc();
        $stS->close();

        if (!$snap || (float) $snap['valor_snapshot'] <= 0) {
            throw new Exception("La OT #$sid no tiene un snapshot financiero válido o es cero.");
        }
        $serviciosData[] = $snap;
    }

    // 4. Mapear Payload para Factus
    $payment_form = ($metodo_pago == 1) ? "1" : "2";
    $factusPayload = [
        'numbering_range_id' => FactusService::getActiveRangeId($conn),
        'reference_code' => "OT-GRP-" . time(), // Referencia de trazabilidad
        'customer' => FactusService::mapCustomer($cliente),
        'items' => FactusService::mapItems($serviciosData, $cliente, $tax_engine_data),
        'observation' => $observaciones,
        'payment_form' => $payment_form,
        'payment_method_code' => ($metodo_pago == 1) ? "10" : "30", // 10: Efectivo, 30: Transferencia
        'is_asynchronous' => false
    ];

    // Para facturas a CRÉDITO, Factus requiere fecha de vencimiento (payment_due_date)
    if ($payment_form === "2") {
        $factusPayload['payment_due_date'] = date('Y-m-d', strtotime('+30 days'));
    }

    // 5. Iniciar Transacción SQL
    $conn->begin_transaction();

    // 6. Enviar a Factus (DIAN)
    try {
        $factusRes = FactusService::sendInvoice($conn, $factusPayload);
    } catch (Exception $e) {
        $msg = $e->getMessage();

        // Manejo estructurado de errores de Factus (Ticket #4.1)
        if (strpos($msg, 'FACTUS_API_ERROR:') === 0) {
            $errorJson = substr($msg, strlen('FACTUS_API_ERROR:'));
            $errorData = json_decode($errorJson, true);
            $resOriginal = $errorData['original_res'] ?? [];
            $status = $resOriginal['status'] ?? null;
            $billId = $resOriginal['data']['bill']['id'] ?? null;

            // Auditoría Local de Intentos Fallidos (Ticket #4.1.3)
            $errorDetail = $errorData['message'] ?? 'Error desconocido';
            $auditNote = "Intento de facturación fallido. Status: $status. Error: " . substr($errorDetail, 0, 500);

            foreach ($servicios_ids as $sid) {
                $sqlLog = "INSERT INTO servicios_logs (servicio_id, to_status_id, user_id, timestamp, notas) 
                           VALUES (?, (SELECT estado FROM servicios WHERE id=?), ?, NOW(), ?)";
                $stLog = $conn->prepare($sqlLog);
                $stLog->bind_param("iiis", $sid, $sid, $currentUser['id'], $auditNote);
                $stLog->execute();
                $stLog->close();
            }

            // Lógica de "Limpieza Atómica" (Status 0 o Validation error) (Ticket #4.1.1)
            $isValidationError = ($status === 0 || $status === "0" || $status === "Validation error");

            if ($isValidationError && $billId) {
                FactusService::deleteBill($conn, $billId);
                $cleanMsg = "Error de Validación DIAN: " . ($resOriginal['message'] ?? 'Datos inválidos') . ". El borrador ha sido descartado de Factus para evitar bloqueos. Por favor, corrija los datos y reintente.";

                // Log de error para diagnóstico
                file_put_contents(__DIR__ . '/factus_debug_error.json', json_encode($resOriginal));

                throw new Exception($cleanMsg);
            }

            // Manejo de Error 409 (Factura Pendiente) dentro de error estructurado
            if (($errorData['http_code'] ?? 0) == 409 || strpos($errorDetail, 'pendiente') !== false) {
                $pending = FactusService::getPendingInvoices($conn);
                $msgArr = ["Existe un documento pendiente en Factus que bloquea la numeración."];

                if (!empty($pending)) {
                    foreach ($pending as $p) {
                        $det = "- Bloqueo en ID Factus: #{$p['id']} (Ref: " . ($p['reference_code'] ?? 'N/A') . ")";
                        $msgArr[] = $det;
                    }
                    $msgArr[] = "Acción Sugerida: Elimine estos borradores en el portal de Factus o contacte a soporte si persisten.";
                } else {
                    $msgArr[] = "Factus reporta una factura pendiente pero no se hallaron borradores visibles para tu cuenta. Verifique el portal de Factus.";
                }
                throw new Exception(implode("\n", $msgArr));
            }

            // Si no es status 0 ni 409, también logueamos el error original para saber qué falló
            file_put_contents(__DIR__ . '/factus_debug_error.json', json_encode($resOriginal));

            throw new Exception("Error Factus API: " . $errorDetail);
        }

        // Manejo Proactivo de Error 409 (Factura Pendiente / Bloqueo de Rango)
        if (strpos($msg, '409') !== false) {
            $pending = FactusService::getPendingInvoices($conn);
            $msgArr = ["Conflict 409: Existe un documento en Factus que bloquea la numeración."];

            if (!empty($pending)) {
                foreach ($pending as $p) {
                    $det = "- Bloqueo en ID: {$p['id']} (Ref: " . ($p['reference_code'] ?? 'N/A') . ")";
                    if (!empty($p['errors'])) {
                        $det .= " | Notas DIAN: " . json_encode($p['errors']);
                    }
                    $msgArr[] = $det;
                }
                $msgArr[] = "Acción: Por favor elimine o valide estos borradores directamente en el portal de Factus.";
            } else {
                $msgArr[] = "Factus reporta un conflicto pero no se hallaron borradores visibles. Verifique el portal de Factus.";
            }

            throw new Exception(implode("\n", $msgArr));
        }
        throw $e;
    }

    // Log para depuración interna
    file_put_contents(__DIR__ . '/factus_debug_res.json', json_encode($factusRes));

    if (!isset($factusRes['data'])) {
        throw new Exception("Respuesta inesperada de Factus API (Faltan 'data').");
    }

    $factura_dian = $factusRes['data'];
    $billData = $factura_dian['bill'] ?? [];
    $rangeData = $factura_dian['numbering_range'] ?? [];

    $prefijo = $billData['prefix'] ?? $rangeData['prefix'] ?? null;
    $numero_completo = $billData['number'] ?? '';

    $numero = $numero_completo;
    if (!empty($prefijo) && strpos($numero_completo, $prefijo) === 0) {
        $numero = substr($numero_completo, strlen($prefijo));
    }

    $cufe = $billData['cufe'] ?? null;
    $qr_url = $billData['qr_url'] ?? $billData['qr'] ?? $billData['qr_image'] ?? null;
    $pdf_url = $billData['public_url'] ?? null;
    $total_neto = (float) ($billData['total'] ?? 0);

    // Persistencia Estricta de Documentos Válidos (Ticket #4.1.2)
    if (empty($prefijo) || empty($numero) || empty($cufe)) {
        $raw = json_encode($factusRes);
        throw new Exception("Datos Legales Incompletos (Falta CUFE/QR). Respuesta de Factus: $raw");
    }

    // 7. Persistir en fac_facturas con Trazabilidad y Respuesta JSON completa
    $sqlInsF = "INSERT INTO fac_facturas (cliente_id, servicio_id, prefijo, numero_factura, cufe, qr_url, pdf_url, raw_response_json, observaciones, metodo_pago, fecha_emision, total_neto, saldo_actual, creado_por, estado) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), ?, ?, ?, 'Exitosa')";
    $stInsF = $conn->prepare($sqlInsF);
    $metodo_label = ($metodo_pago == 1) ? 'CONTADO' : 'CREDITO';
    $primary_sid = $servicios_ids[0];

    $full_json = json_encode($factusRes);

    $stInsF->bind_param(
        "iissssssssddi",
        $cliente_id,
        $primary_sid,
        $prefijo,
        $numero,
        $cufe,
        $qr_url,
        $pdf_url,
        $full_json,
        $observaciones,
        $metodo_label,
        $total_neto,
        $total_neto,
        $currentUser['id']
    );
    $stInsF->execute();
    $factura_id = $conn->insert_id;
    $stInsF->close();

    // 8. Vincular OTs y Actualizar Estados
    $subtotal_factura = 0;
    $total_iva = 0;

    foreach ($serviciosData as $s) {
        $sid = $s['servicio_id'];
        $m_rep = (float) $s['total_repuestos'];
        $m_mo = (float) $s['total_mano_obra'];
        $base = (float) $s['valor_snapshot'];
        $iva = round($base * 0.19, 2);

        $subtotal_factura += $base;
        $total_iva += $iva;

        $sqlItem = "INSERT INTO fac_factura_items (factura_id, servicio_id, monto_repuestos, monto_mano_obra, base_iva, valor_iva, subtotal_item) 
                    VALUES (?, ?, ?, ?, ?, ?, ?)";
        $stI = $conn->prepare($sqlItem);
        $total_item = $base + $iva;
        $stI->bind_param("iiddddd", $factura_id, $sid, $m_rep, $m_mo, $base, $iva, $total_item);
        $stI->execute();
        $stI->close();

        // Automatización: Recalcular estado comercial
        AccountingEngine::recalculateCommercialState($conn, $sid);
    }

    // 9. Registrar Asiento Contable Oficial (OT 1288 - Sincronizado con Preview)
    $referencia = "$prefijo-$numero";

    $retenciones_calc = FactusService::calculateWithholdings($subtotal_factura, $cliente, $tax_engine_data);
    $extraDetalles = [];
    $total_retenciones = 0;

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
                'tipo' => 'DEBITO',
                'valor' => $monto
            ];
        }
    }

    $total_neto_real = ($subtotal_factura + $total_iva) - $total_retenciones;

    $montosAsiento = [
        'TOTAL' => $total_neto_real,
        'SUBTOTAL' => $subtotal_factura,
        'IMPUESTO' => $total_iva,
        'REPUESTOS' => array_sum(array_column($serviciosData, 'total_repuestos')),
        'MANO_OBRA' => array_sum(array_column($serviciosData, 'total_mano_obra'))
    ];

    $asientoData = AccountingEngine::generateEntry($conn, 'GENERAR_FACTURA', $montosAsiento, $referencia, $extraDetalles);

    $sqlAsH = "INSERT INTO fin_asientos (referencia, fecha, evento_codigo, total_debito, total_credito, creado_por) VALUES (?, CURDATE(), 'GENERAR_FACTURA', ?, ?, ?)";
    $stAsH = $conn->prepare($sqlAsH);
    $stAsH->bind_param("sddi", $referencia, $total_neto, $total_neto, $currentUser['id']);
    $stAsH->execute();
    $asiento_id = $conn->insert_id;
    $stAsH->close();

    foreach ($asientoData['detalles'] as $det) {
        $sqlDet = "INSERT INTO fin_asientos_detalle (asiento_id, puc_cuenta_id, tipo_movimiento, valor, descripcion) VALUES (?, ?, ?, ?, ?)";
        $stDet = $conn->prepare($sqlDet);
        $desc = "Factura $referencia - " . $det['nombre'];
        $stDet->bind_param("iisds", $asiento_id, $det['cuenta_id'], $det['tipo'], $det['valor'], $desc);
        $stDet->execute();
        $stDet->close();
    }

    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => "Factura Electrónica $prefijo-$numero emitida exitosamente.",
        'data' => [
            'factura_id' => $factura_id,
            'numero_dian' => "$prefijo-$numero",
            'pdf_url' => $pdf_url,
            'cufe' => $cufe
        ]
    ]);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    error_log("Legal Invoicing Error: " . $e->getMessage());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
