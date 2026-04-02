<?php
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json; charset=UTF-8");
header("Access-Control-Allow-Methods: GET");
header("Access-Control-Allow-Headers: Content-Type, Access-Control-Allow-Headers, Authorization, X-Requested-With");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

define('AUTH_REQUIRED', true);
require_once __DIR__ . '/../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php'; // Usa $conn local

$auth = requireAuth();

try {
    // $conn ya viene de conexion.php

    // Consulta de facturas emitidas con datos del cliente
    $sql = "SELECT 
                f.id,
                f.prefijo,
                f.numero_factura,
                f.cufe,
                f.qr_url,
                f.pdf_url,
                f.metodo_pago,
                f.fecha_emision,
                f.total_neto,
                f.saldo_actual,
                c.nombre_completo as cliente_nombre,
                c.documento_nit as cliente_nit,
                IFNULL(fin_state.estado_financiero_id, 0) as estado_financiero_id,
                IFNULL(NULLIF(fin_state.nombre_estado, ''), 'Facturado') as estado_financiero_nombre,
                IFNULL(NULLIF(fin_state.color, ''), '#4CAF50') as estado_financiero_color,
                IFNULL(NULLIF(fin_state.estado_base_codigo, ''), 'FIN_FACTURADO') as estado_financiero_codigo,
                (SELECT GROUP_CONCAT(DISTINCT s.o_servicio) FROM fac_factura_items fi JOIN servicios s ON fi.servicio_id = s.id WHERE fi.factura_id = f.id) as servicios_ids
            FROM fac_facturas f
            JOIN clientes c ON f.cliente_id = c.id
            LEFT JOIN (
                 SELECT fi.factura_id, s.estado_financiero_id, ep.nombre_estado, ep.color, ep.estado_base_codigo
                 FROM fac_factura_items fi
                 JOIN servicios s ON fi.servicio_id = s.id
                 JOIN estados_proceso ep ON s.estado_financiero_id = ep.id
                 GROUP BY fi.factura_id, s.estado_financiero_id, ep.nombre_estado, ep.color, ep.estado_base_codigo
            ) AS fin_state ON f.id = fin_state.factura_id
            ORDER BY f.fecha_emision DESC";

    $result = $conn->query($sql);
    $facturas = [];

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            // Formatear para el frontend
            $row['total_neto'] = (float) $row['total_neto'];
            $row['saldo_actual'] = (float) $row['saldo_actual'];
            $facturas[] = $row;
        }
    }

    echo json_encode([
        "success" => true,
        "data" => $facturas
    ]);

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        "success" => false,
        "error" => "Error al listar facturas",
        "message" => $e->getMessage()
    ]);
} finally {
    if (isset($conn))
        $conn->close();
}
