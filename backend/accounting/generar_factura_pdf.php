<?php
/**
 * generar_factura_pdf.php
 * Genera el PDF legal de la factura basado en el Mockup v2.
 */

define('AUTH_REQUIRED', true);
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/../core/FactusConfig.php';

use Mpdf\Mpdf;

// Si el token viene por URL con 'Bearer ', limpiarlo para que auth_middleware no falle
if (isset($_GET['token'])) {
    $_GET['token'] = str_replace('Bearer ', '', $_GET['token']);
}

try {
    $auth = requireAuth();

    if (!isset($_GET['id'])) {
        die("ID de factura no proporcionado.");
    }

    $factura_id = (int) $_GET['id'];
    // $conn ya viene de conexion.php

    // 1. Obtener cabecera de la factura y datos del cliente (Perfil Fiscal Completo)
    $sqlF = "SELECT f.*, 
                c.nombre_completo as cliente_nombre, c.documento_nit as cliente_nit, c.dv as cliente_dv,
                c.direccion as cliente_direccion, c.telefono_principal as cliente_telefono, 
                c.email as cliente_email, c.email_facturacion,
                c.es_gran_contribuyente, c.es_autorretenedor, c.es_agente_retenedor,
                c.regimen_tributario, c.responsabilidad_fiscal_id,
                c.ciudad_id, c.codigo_ciiu
             FROM fac_facturas f
             JOIN clientes c ON f.cliente_id = c.id
             WHERE f.id = ?";
    $stF = $conn->prepare($sqlF);
    $stF->bind_param("i", $factura_id);
    $stF->execute();
    $factura = $stF->get_result()->fetch_assoc();
    $stF->close();

    if (!$factura)
        throw new Exception("Factura no encontrada.");

    // 1.1 Carga Dinámica de Configuración Tributaria (Sincronizada con create_invoice)
    require_once __DIR__ . '/../core/FactusService.php';
    $tax_engine_data = [
        'IVA' => FactusService::getTaxConfigs($conn, 'IVA'),
        'RETEFUENTE' => FactusService::getTaxConfigs($conn, 'RETEFUENTE'),
        'RETEICA' => []
    ];

    // Lógica ReteICA Jerárquica: Ciudad -> CIIU -> Global
    $ciudad_id = $factura['ciudad_id'] ?? null;
    if ($ciudad_id) {
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA');
    } else {
        $ciiu = !empty($factura['codigo_ciiu']) ? $factura['codigo_ciiu'] : null;
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

    // 2. Obtener items (OTs vinculadas) con Nombres Reales (Phase 3.7)
    $sqlItems = "SELECT fi.*, s.tipo_mantenimiento, ae.actividad as nombre_servicio, s.o_servicio as numero_orden
                 FROM fac_factura_items fi
                 JOIN servicios s ON fi.servicio_id = s.id
                 LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                 WHERE fi.factura_id = ?";
    $stI = $conn->prepare($sqlItems);
    $stI->bind_param("i", $factura_id);
    $stI->execute();
    $items = $stI->get_result();

    $ots_detalles = [];
    while ($item = $items->fetch_assoc()) {
        $sid = $item['servicio_id'];

        // Obtener detalle de Mano de Obra para esta OT
        $sqlMO = "SELECT o.fecha_inicio, o.fecha_fin, e.nom_especi as NOMBRE_ESPECIALIDAD, o.descripcion as actividad
                  FROM servicio_staff ss
                  JOIN usuarios u ON ss.staff_id = u.id
                  JOIN especialidades e ON u.ID_ESPECIALIDAD = e.id
                  LEFT JOIN operaciones o ON ss.operacion_id = o.id
                  WHERE ss.servicio_id = ? AND o.fecha_fin IS NOT NULL";
        $stMO = $conn->prepare($sqlMO);
        $stMO->bind_param("i", $sid);
        $stMO->execute();
        $labor_rows = $stMO->get_result()->fetch_all(MYSQLI_ASSOC);
        $stMO->close();

        $ots_detalles[] = [
            'item' => $item,
            'labor' => $labor_rows
        ];
    }
    $stI->close();

    // --- MEJORA: Obtener Datos del Emisor (Admin) y Branding ---
    $emisor = [
        'nombre' => 'INFOAPP SERVICES SAS', 
        'nit' => '900.000.000-1', 
        'email' => 'contabilidad@infoapp.com',
        'direccion' => '',
        'telefono' => '',
        'sitio_web' => '',
        'resolucion' => '',
        'ciudad' => ''
    ];

    $sqlEmisor = "SELECT NOMBRE_CLIENTE, CORREO, NIT, DIRECCION, TELEFONO, SITIO_WEB, RESOLUCION_DIAN, CIUDAD 
                  FROM usuarios 
                  WHERE TIPO_ROL = 'admin' AND NOMBRE_USER = 'administrator' LIMIT 1";
    if ($resE = $conn->query($sqlEmisor)) {
        if ($rowE = $resE->fetch_assoc()) {
            $emisor['nombre'] = strtoupper($rowE['NOMBRE_CLIENTE']);
            $emisor['nit'] = $rowE['NIT'];
            $emisor['email'] = $rowE['CORREO'];
            $emisor['direccion'] = $rowE['DIRECCION'] ?? '';
            $emisor['telefono'] = $rowE['TELEFONO'] ?? '';
            $emisor['sitio_web'] = $rowE['SITIO_WEB'] ?? '';
            $emisor['resolucion'] = $rowE['RESOLUCION_DIAN'] ?? '';
            $emisor['ciudad'] = $rowE['CIUDAD'] ?? '';
        } else {
            // Fallback a cualquier admin si administrator no existe
            $sqlAnyAdmin = "SELECT NOMBRE_CLIENTE, CORREO, NIT, DIRECCION, TELEFONO FROM usuarios WHERE TIPO_ROL = 'admin' LIMIT 1";
            if ($resAny = $conn->query($sqlAnyAdmin)) {
                if ($rowAny = $resAny->fetch_assoc()) {
                    $emisor['nombre'] = strtoupper($rowAny['NOMBRE_CLIENTE']);
                    $emisor['nit'] = $rowAny['NIT'];
                    $emisor['email'] = $rowAny['CORREO'];
                    $emisor['direccion'] = $rowAny['DIRECCION'] ?? '';
                    $emisor['telefono'] = $rowAny['TELEFONO'] ?? '';
                }
            }
        }
    }

    $logoDataUri = null;
    $sqlBranding = "SELECT logo_url FROM branding WHERE id = 1";
    if ($resB = $conn->query($sqlBranding)) {
        if ($rowB = $resB->fetch_assoc()) {
            $logoUrl = $rowB['logo_url'];
            if ($logoUrl) {
                $apiRoot = dirname(__DIR__);
                $fullPath = $apiRoot . '/' . ltrim($logoUrl, '/');
                if (is_file($fullPath)) {
                    $bytes = @file_get_contents($fullPath);
                    $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
                    $mime = ($ext === 'jpg' || $ext === 'jpeg') ? 'image/jpeg' : 'image/png';
                    if ($bytes)
                        $logoDataUri = 'data:' . $mime . ';base64,' . base64_encode($bytes);
                }
            }
        }
    }

    // 3. Construir HTML (Estilo CLÁSICO PERSONALIZADO - Robusto y Elegante)
    $html = '
    <html>
    <head>
    <style>
        body { font-family: "Helvetica", sans-serif; color: #333; font-size: 10px; margin: 0; padding: 0; }
        .invoice-box { padding: 10px; }
        
        /* Cabecera Clásica Equilibrada */
        .header-main { width: 100%; border-bottom: 2px solid #5a2d82; padding-bottom: 10px; margin-bottom: 20px; }
        .logo-box { width: 30%; vertical-align: middle; text-align: left; }
        .issuer-box { width: 40%; text-align: center; vertical-align: top; line-height: 1.3; }
        .qr-box { width: 30%; text-align: right; vertical-align: middle; }
        
        .company-name { font-size: 16px; font-weight: bold; color: #5a2d82; margin-bottom: 5px; }
        .company-subtitle { font-size: 9px; color: #64748b; }
        
        /* Bloques de Datos */
        .info-grid { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        .info-table { width: 100%; border: 1px solid #e2e8f0; }
        .info-table td { padding: 5px 8px; border: 1px solid #f1f5f9; }
        .info-label { font-weight: bold; color: #5a2d82; font-size: 8px; text-transform: uppercase; width: 80px; }
        
        .invoice-banner { background: #f8fafc; border: 1px solid #e2e8f0; padding: 10px; text-align: center; }
        .invoice-title { font-size: 11px; font-weight: bold; color: #1e293b; margin-bottom: 4px; }
        .invoice-number { font-size: 16px; font-weight: bold; color: #5a2d82; }
        
        /* Tabla de Productos/Servicios */
        .items-container { width: 100%; border-collapse: collapse; margin-top: 10px; }
        .items-header th { background: #5a2d82; color: white; padding: 10px; text-align: left; font-size: 10px; }
        .item-row td { padding: 10px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
        .ot-group-title { background: #fdfaf5; border-left: 4px solid #5a2d82; font-weight: bold; color: #5a2d82; padding: 6px 10px; margin-top: 10px; font-size: 10px; }
        
        /* Totales y Retenciones */
        .summary-wrapper { width: 100%; margin-top: 20px; }
        .totals-table { width: 280px; margin-left: auto; border-collapse: collapse; background: #f8fafc; border: 1px solid #e2e8f0; }
        .totals-table td { padding: 6px 10px; border-bottom: 1px solid #edf2f7; text-align: right; }
        .final-amount-row { background: #5a2d82; color: #ffffff !important; font-weight: bold; font-size: 14px; }
        
        /* Pie de Página Legales */
        .cufe-box { background: #fff; padding: 10px; border: 1px dashed #cbd5e1; font-family: monospace; font-size: 9px; margin-top: 25px; color: #475569; word-break: break-all; }
        .footer-text { margin-top: 15px; font-size: 8px; color: #94a3b8; text-align: center; border-top: 1px solid #f1f5f9; padding-top: 10px; }
    </style>
    </head>
    <body>
    <div class="invoice-box">
        <!-- Header: Logo (L) | Empresa (C) | QR (R) -->
        <table class="header-main">
            <tr>
                <td class="logo-box">
                    ' . ($logoDataUri ? '<img src="' . $logoDataUri . '" style="max-height:110px; width:auto;"/>' : '<div style="font-size:24px; font-weight:bold; color:#5a2d82;">' . $emisor['nombre'] . '</div>') . '
                </td>
                <td class="issuer-box">
                    <div class="company-name">' . $emisor['nombre'] . '</div>
                    <div class="company-subtitle">
                        NIT: ' . $emisor['nit'] . ' | EMAIL: ' . $emisor['email'] . '<br>
                        ' . (!empty($emisor['direccion']) ? 'DIRECCIÓN: ' . $emisor['direccion'] : '') . 
                        (!empty($emisor['ciudad']) ? ' - ' . $emisor['ciudad'] : '') . 
                        (!empty($emisor['telefono']) ? ' | TEL: ' . $emisor['telefono'] : '') . '<br>
                        ' . (!empty($emisor['sitio_web']) ? 'SITIO WEB: ' . $emisor['sitio_web'] : '') . '
                    </div>
                </td>
                <td class="qr-box">
                    ' . ($factura['qr_url'] ? '<img src="' . $factura['qr_url'] . '" width="105">' : '<div style="font-size:8px; color:#cbd5e1;">QR NO DISPONIBLE EN PREVIEW</div>') . '
                </td>
            </tr>
        </table>

        <!-- Bloque Información General -->
        <table width="100%" class="info-grid">
            <tr>
                <td style="width: 62%; vertical-align: top; padding-right: 15px;">
                    <table class="info-table">
                        <tr>
                            <td class="info-label">Adquiriente</td>
                            <td style="font-weight:bold; font-size:10px;">' . strtoupper($factura['cliente_nombre']) . '</td>
                        </tr>
                        <tr>
                            <td class="info-label">NIT / CC</td>
                            <td>' . $factura['cliente_nit'] . ($factura['cliente_dv'] !== null ? '-' . $factura['cliente_dv'] : '') . '</td>
                        </tr>
                        <tr>
                            <td class="info-label">Régimen</td>
                            <td>' . ($factura['regimen_tributario'] ?? 'No Responsable de IVA') . ' (' . ($factura['responsabilidad_fiscal_id'] ?? 'R-99-PN') . ')</td>
                        </tr>
                        <tr>
                            <td class="info-label">Dirección</td>
                            <td>' . $factura['cliente_direccion'] . '</td>
                        </tr>
                        <tr>
                            <td class="info-label">Contacto</td>
                            <td>' . (!empty($factura['email_facturacion']) ? $factura['email_facturacion'] : $factura['cliente_email']) . ' | ' . $factura['cliente_telefono'] . '</td>
                        </tr>
                    </table>
                </td>
                <td style="width: 38%; vertical-align: top;">
                    <div class="invoice-banner">
                        <div class="invoice-title">FACTURA ELECTRÓNICA DE VENTA</div>
                        <div class="invoice-number">' . $factura['prefijo'] . '-' . $factura['numero_factura'] . '</div>
                        <div style="margin-top:8px; font-size:9px; color:#64748b; text-align: left;">
                            Fecha Emisión: ' . date("Y-m-d H:i", strtotime($factura['fecha_emision'])) . '<br>
                            Fecha Vencimiento: ' . date("Y-m-d", strtotime($factura['fecha_emision'] . " + 30 days")) . '
                        </div>
                    </div>
                </td>
            </tr>
        </table>

        <!-- Listado de Items Agrupados por OT -->
        <table class="items-container">
            <thead class="items-header">
                <tr>
                    <th style="width:15%;">Referencia</th>
                    <th style="width:50%;">Descripción del Servicio / OT</th>
                    <th style="width:10%; text-align:center;">Unid</th>
                    <th style="width:25%; text-align:right;">Monto Total</th>
                </tr>
            </thead>
            <tbody>';

    foreach ($ots_detalles as $det) {
        $sid = $det['item']['servicio_id'];
        $nombreServicio = $det['item']['nombre_servicio'] ?? 'SERVICIO TÉCNICO ESPECIALIZADO';

        $html .= '<tr>
                    <td colspan="4" class="ot-group-title">ÓRDEN DE TRABAJO #' . strtoupper($det['item']['numero_orden']) . ' - ' . strtoupper($det['item']['tipo_mantenimiento']) . '</td>
                  </tr>';

        // Mano de Obra Consolidada con Nombre Real
        $html .= '<tr class="item-row">
                    <td>MO-' . $det['item']['numero_orden'] . '</td>
                    <td>' . strtoupper($nombreServicio) . ' (MANO DE OBRA)</td>
                    <td style="text-align:center;">UND</td>
                    <td style="text-align:right;">$ ' . number_format($det['item']['monto_mano_obra'], 2) . '</td>
                  </tr>';

        // Repuestos si aplica
        if ($det['item']['monto_repuestos'] > 0) {
            $html .= '<tr class="item-row">
                        <td>RP-' . $det['item']['numero_orden'] . '</td>
                        <td>REPUESTOS E INSUMOS PARA: ' . strtoupper($nombreServicio) . '</td>
                        <td style="text-align:center;">UND</td>
                        <td style="text-align:right;">$ ' . number_format($det['item']['monto_repuestos'], 2) . '</td>
                      </tr>';
        }
    }

    // --- LÓGICA DE IMPUESTOS DINÁMICA (Sincronizada con Multi-Concepto) ---
    $subtotal = 0;
    foreach ($ots_detalles as $d) {
        $subtotal += (float) $d['item']['monto_mano_obra'] + (float) $d['item']['monto_repuestos'];
    }

    $retenciones_calc = FactusService::calculateWithholdings($subtotal, $factura, $tax_engine_data);

    // El IVA se calcula estándar al 19% por ahora o desde el primer config
    $iva_pct = $tax_engine_data['IVA'][0]['porcentaje'] ?? 19.00;
    $iva = round($subtotal * ($iva_pct / 100), 2);

    $total_retenciones = 0;
    $retenciones_html = '';

    foreach ($retenciones_calc as $ret) {
        $monto_ret = (float) $ret['amount'];
        $total_retenciones += $monto_ret;
        $retenciones_html .= '<tr>
                                <td style="text-align:left; color:#ef4444;">' . $ret['name'] . ':</td>
                                <td>- $ ' . number_format($monto_ret, 2) . '</td>
                              </tr>';
    }

    $total_a_pagar = ($subtotal + $iva) - $total_retenciones;

    $html .= '
            </tbody>
        </table>
        
        <div style="margin-top:20px; font-size: 11px;">
            <strong>Observaciones:</strong><br>
            ' . nl2br(htmlspecialchars($factura['observaciones'] ?? 'S/O')) . '
        </div>

        <!-- Resumen Financiero: MOTOR FISCAL ACTUALIZADO -->
        <div class="summary-wrapper">
            <table class="totals-table">
                <tr>
                    <td style="text-align:left; color:#64748b;">Subtotal Neto:</td>
                    <td>$ ' . number_format($subtotal, 2) . '</td>
                </tr>
                <tr>
                    <td style="text-align:left; color:#64748b;">IVA (' . number_format($iva_pct, 0) . '%):</td>
                    <td>$ ' . number_format($iva, 2) . '</td>
                </tr>
                ' . $retenciones_html . '
                <tr class="final-amount-row">
                    <td style="text-align:left;">NETO A PAGAR:</td>
                    <td>$ ' . number_format($total_a_pagar, 2) . '</td>
                </tr>
            </table>
        </div>

        <!-- Identificadores Legales -->
        <div class="cufe-box">
            <strong>IDENTIFICADOR CUFE:</strong><br>
            ' . $factura['cufe'] . '
        </div>

        <div class="footer-text">
            ' . (!empty($emisor['resolucion']) ? $emisor['resolucion'] . '<br>' : '') . '
            Esta es una representación gráfica de la factura electrónica. Generado por InfoApp ERP.<br>
            La validez legal y el estado en la DIAN pueden consultarse escaneando el código QR.
        </div>
    </div>
    </body>
    </html>';

    // 4. Renderizar PDF
    $mpdf = new Mpdf([
        'margin_left' => 15,
        'margin_right' => 15,
        'margin_top' => 15,
        'margin_bottom' => 20,
    ]);

    $mpdf->WriteHTML($html);
    $mpdf->Output('Factura_' . $factura['prefijo'] . '_' . $factura['numero_factura'] . '.pdf', 'I');

} catch (Exception $e) {
    echo "Error al generar PDF: " . $e->getMessage();
} finally {
    $conn->close();
}
