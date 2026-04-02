<?php
/**
 * generar_cotizacion_pdf.php
 * Genera un PDF de Cotización Pro-forma basado en el diseño de factura legal.
 * No constituye factura de venta ni título valor.
 */

define('AUTH_REQUIRED', true);
require_once __DIR__ . '/../vendor/autoload.php';
require_once __DIR__ . '/../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php';
require_once __DIR__ . '/../core/FactusConfig.php';
require_once __DIR__ . '/../core/FactusService.php';

use Mpdf\Mpdf;

// Limpiar token si viene por URL
if (isset($_GET['token'])) {
    $_GET['token'] = str_replace('Bearer ', '', $_GET['token']);
}

try {
    $auth = requireAuth();

    if (!isset($_GET['servicio_id'])) {
        die("ID de servicio no proporcionado.");
    }

    $servicio_id = (int) $_GET['servicio_id']; // ID del servicio a cotizar

    // 1. Obtener datos del Snapshot y Cliente
    $sqlS = "SELECT fcs.*, s.o_servicio as numero_orden, s.cliente_id, s.tipo_mantenimiento,
                    c.nombre_completo as cliente_nombre, c.documento_nit as cliente_nit, c.dv as cliente_dv,
                    c.direccion as cliente_direccion, c.telefono_principal as cliente_telefono, 
                    c.email as cliente_email, c.email_facturacion,
                    c.es_gran_contribuyente, c.es_autorretenedor, c.es_agente_retenedor,
                    c.regimen_tributario, c.responsabilidad_fiscal_id,
                    c.ciudad_id, c.codigo_ciiu,
                    ae.actividad as nombre_servicio,
                    fcs.ver_detalle_cotizacion
             FROM fac_control_servicios fcs
             JOIN servicios s ON fcs.servicio_id = s.id
             JOIN clientes c ON s.cliente_id = c.id
             LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
             WHERE fcs.servicio_id = ?";

    $stS = $conn->prepare($sqlS);
    $stS->bind_param("i", $servicio_id);
    $stS->execute();
    $servicio = $stS->get_result()->fetch_assoc();
    $stS->close();

    if (!$servicio)
        throw new Exception("No existe snapshot financiero para este servicio.");

    // 2. Obtener Observaciones de la Operación Maestra (Requerimiento 3.8/3.13)
    $sqlObs = "SELECT observaciones FROM operaciones WHERE servicio_id = ? AND is_master = 1 LIMIT 1";
    $stObs = $conn->prepare($sqlObs);
    $stObs->bind_param("i", $servicio_id);
    $stObs->execute();
    $resObs = $stObs->get_result()->fetch_assoc();
    $observaciones_maestra = $resObs['observaciones'] ?? 'Sin observaciones adicionales.';
    $stObs->close();

    // 3. Carga Dinámica de Configuración Tributaria
    $tax_engine_data = [
        'IVA' => FactusService::getTaxConfigs($conn, 'IVA'),
        'RETEFUENTE' => FactusService::getTaxConfigs($conn, 'RETEFUENTE'),
        'RETEICA' => []
    ];

    $ciudad_id = $servicio['ciudad_id'] ?? null;
    if ($ciudad_id) {
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA');
    } else {
        $ciiu = !empty($servicio['codigo_ciiu']) ? $servicio['codigo_ciiu'] : null;
        $tax_engine_data['RETEICA'] = FactusService::getTaxConfigs($conn, 'RETEICA', $ciiu);
    }
    if (empty($tax_engine_data['RETEICA'])) {
        $tax_engine_data['RETEICA'] = [['nombre_impuesto' => 'ReteICA (Global)', 'tarifa_x_mil' => 9.66, 'base_minima_pesos' => 0]];
    }

    // 4. Obtener Repuestos Detallados (Phase 3.9)
    $sqlRep = "SELECT i.name as item_nombre, sr.cantidad, sr.costo_unitario 
               FROM servicio_repuestos sr
               JOIN inventory_items i ON sr.inventory_item_id = i.id
               WHERE sr.servicio_id = ?";
    $stRep = $conn->prepare($sqlRep);
    $stRep->bind_param("i", $servicio_id);
    $stRep->execute();
    $repuestos = $stRep->get_result()->fetch_all(MYSQLI_ASSOC);
    $stRep->close();

    // --- MEJORA: Branding ---
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
            // Fallback to any admin if administrator doesn't exist
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
                $fullPath = dirname(__DIR__) . '/' . ltrim($logoUrl, '/');
                if (is_file($fullPath)) {
                    $bytes = @file_get_contents($fullPath);
                    if ($bytes)
                        $logoDataUri = 'data:image/png;base64,' . base64_encode($bytes);
                }
            }
        }
    }

    // 5. Cálculos Financieros
    $subtotal = (float) $servicio['valor_snapshot'];
    // Eliminadas las deducciones para la Cotización Pro-forma (Requerimiento Usuario)
    $iva_pct = $tax_engine_data['IVA'][0]['porcentaje'] ?? 19.00;
    $iva = round($subtotal * ($iva_pct / 100), 2);

    $total_retenciones = 0;
    $retenciones_html = '';
    // --- Cálculo de retenciones omitido en cotización ---
    $total_a_pagar = ($subtotal + $iva);

    // 6. Construir HTML
    $html = '
    <html>
    <head>
    <style>
        body { font-family: "Helvetica", sans-serif; color: #333; font-size: 10px; margin: 0; padding: 0; }
        .invoice-box { padding: 10px; }
        .header-main { width: 100%; border-bottom: 2px solid #5a2d82; padding-bottom: 10px; margin-bottom: 20px; }
        .logo-box { width: 30%; vertical-align: middle; text-align: left; }
        .issuer-box { width: 70%; text-align: right; vertical-align: top; line-height: 1.3; }
        .company-name { font-size: 16px; font-weight: bold; color: #5a2d82; margin-bottom: 5px; }
        .company-subtitle { font-size: 9px; color: #64748b; }
        .info-grid { width: 100%; border-collapse: collapse; margin-bottom: 20px; }
        .info-table { width: 100%; border: 1px solid #e2e8f0; }
        .info-table td { padding: 5px 8px; border: 1px solid #f1f5f9; }
        .info-label { font-weight: bold; color: #5a2d82; font-size: 8px; text-transform: uppercase; width: 80px; }
        .banner { background: #f8fafc; border: 1px solid #e2e8f0; padding: 10px; text-align: center; }
        .banner-title { font-size: 11px; font-weight: bold; color: #5a2d82; margin-bottom: 4px; }
        .banner-number { font-size: 14px; font-weight: bold; color: #1e293b; }
        .items-container { width: 100%; border-collapse: collapse; margin-top: 10px; }
        .items-header th { background: #5a2d82; color: white; padding: 10px; text-align: left; font-size: 10px; }
        .item-row td { padding: 10px; border-bottom: 1px solid #f1f5f9; vertical-align: top; }
        .summary-wrapper { width: 100%; margin-top: 20px; }
        .totals-table { width: 280px; margin-left: auto; border-collapse: collapse; border: 1px solid #e2e8f0; }
        .totals-table td { padding: 8px 10px; border-bottom: 1px solid #edf2f7; text-align: right; font-size: 10px; }
        .final-amount-row { color: #1e293b; font-weight: bold; font-size: 14px; border-top: 2px solid #1e293b; }
        .footer-text { margin-top: 30px; font-size: 8px; color: #94a3b8; text-align: center; border-top: 1px solid #f1f5f9; padding-top: 15px; font-style: italic; }
        .legal-notice { background: #fffbeb; border: 1px solid #fde68a; color: #92400e; padding: 8px; font-size: 9px; margin-top: 10px; border-radius: 4px; }
    </style>
    </head>
    <body>
    <div class="invoice-box">
        <table class="header-main">
            <tr>
                <td class="logo-box">
                    ' . ($logoDataUri ? '<img src="' . $logoDataUri . '" style="max-height:80px; width:auto;"/>' : '<div style="font-size:20px; font-weight:bold; color:#5a2d82;">' . $emisor['nombre'] . '</div>') . '
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
            </tr>
        </table>

        <table width="100%" class="info-grid">
            <tr>
                <td style="width: 60%; vertical-align: top; padding-right: 15px;">
                    <table class="info-table">
                        <tr><td class="info-label">Cliente</td><td style="font-weight:bold;">' . strtoupper($servicio['cliente_nombre']) . '</td></tr>
                        <tr><td class="info-label">NIT / CC</td><td>' . $servicio['cliente_nit'] . ($servicio['cliente_dv'] !== null ? '-' . $servicio['cliente_dv'] : '') . '</td></tr>
                        <tr><td class="info-label">Dirección</td><td>' . $servicio['cliente_direccion'] . '</td></tr>
                        <tr><td class="info-label">Contacto</td><td>' . (!empty($servicio['email_facturacion']) ? $servicio['email_facturacion'] : $servicio['cliente_email']) . ' | ' . $servicio['cliente_telefono'] . '</td></tr>
                    </table>
                </td>
                <td style="width: 40%; vertical-align: top;">
                    <div class="banner">
                        <div class="banner-title">COTIZACIÓN / PRO-FORMA</div>
                        <div class="banner-number">REF: OT-' . $servicio['numero_orden'] . '</div>
                        <div style="margin-top:8px; font-size:9px; color:#64748b; text-align: left;">
                            Fecha: ' . date("Y-m-d") . '<br>
                            <strong>Validez de Oferta: 5 días calendario</strong>
                        </div>
                    </div>
                </td>
            </tr>
        </table>

        <table class="items-container">
            <thead class="items-header">
                <tr>
                    <th style="width:15%;">Código</th>
                    <th style="width:50%;">Descripción Detallada</th>
                    <th style="width:10%; text-align:center;">Unid</th>
                    <th style="width:25%; text-align:right;">Valor</th>
                </tr>
            </thead>
            <tbody>';

    if ((int) ($servicio['ver_detalle_cotizacion'] ?? 1) === 0) {
        $html .= '
                <tr class="item-row">
                    <td>SV-' . $servicio['numero_orden'] . '</td>
                    <td><strong>SERVICIO INTEGRAL DE MANTENIMIENTO:</strong> ' . strtoupper($servicio['nombre_servicio'] ?? 'OT-' . $servicio['numero_orden']) . '</td>
                    <td style="text-align:center;">GLB</td>
                    <td style="text-align:right;">$ ' . number_format($subtotal, 2) . '</td>
                </tr>';
    } else {
        $html .= '
                <tr class="item-row">
                    <td>MO-' . $servicio_id . '</td>
                    <td>' . strtoupper($servicio['nombre_servicio'] ?? 'Servicio Técnico') . ' (Mano de Obra)</td>
                    <td style="text-align:center;">GLB</td>
                    <td style="text-align:right;">$ ' . number_format($servicio['total_mano_obra'], 2) . '</td>
                </tr>';

        foreach ($repuestos as $r) {
            $html .= '
                <tr class="item-row">
                    <td>RE-INV</td>
                    <td>' . strtoupper($r['item_nombre']) . '</td>
                    <td style="text-align:center;">' . $r['cantidad'] . '</td>
                    <td style="text-align:right;">$ ' . number_format($r['cantidad'] * $r['costo_unitario'], 2) . '</td>
                </tr>';
        }
    }

    $html .= '
            </tbody>
        </table>

        <div style="margin-top:20px;">
            <strong>Observaciones / Condiciones Especiales:</strong><br>
            <div style="border: 1px solid #f1f5f9; padding: 10px; margin-top: 5px; color: #475569; min-height: 40px;">
                ' . nl2br(htmlspecialchars($observaciones_maestra)) . '
            </div>
        </div>

        <div class="summary-wrapper">
            <table class="totals-table">
                <tr><td style="text-align:left; color:#64748b;">Subtotal:</td><td>$ ' . number_format($subtotal, 2) . '</td></tr>
                <tr><td style="text-align:left; color:#64748b;">IVA (' . number_format($iva_pct, 0) . '%):</td><td>$ ' . number_format($iva, 2) . '</td></tr>
                ' . $retenciones_html . '
                <tr class="final-amount-row">
                    <td style="text-align:left;">TOTAL COTIZACIÓN:</td>
                    <td>$ ' . number_format($total_a_pagar, 2) . '</td>
                </tr>
            </table>
        </div>

        <div class="legal-notice">
            <strong>AVISO IMPORTANTE:</strong> Este documento es una cotización pro-forma con fines informativos y de aprobación comercial. 
            No constituye una factura de venta, no genera obligaciones de pago inmediatas ni es un título valor. 
            Los precios están sujetos a cambios después de la fecha de validez.
        </div>

        <div class="footer-text">
            ' . (!empty($emisor['resolucion']) ? $emisor['resolucion'] . '<br>' : '') . '
            "Este documento es una cotización pro-forma y no constituye una factura de venta ni un título valor. Válido por 5 días."<br>
            Sistema de Gestión Financiera InfoApp.
        </div>
    </div>
    </body>
    </html>';

    $mpdf = new Mpdf(['margin_left' => 15, 'margin_right' => 15, 'margin_top' => 15, 'margin_bottom' => 20]);
    $mpdf->WriteHTML($html);
    $mpdf->Output('Cotizacion_OT_' . $servicio['numero_orden'] . '.pdf', 'I');

} catch (Exception $e) {
    echo "Error al generar Cotización: " . $e->getMessage();
} finally {
    if (isset($conn))
        $conn->close();
}
