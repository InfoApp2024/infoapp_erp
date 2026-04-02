<?php
/**
 * listar_servicios_pendientes.php
 * Lista servicios en estado LEGALIZADO que no han sido facturados (Dashboard Financiero)
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $sql = "SELECT s.id, s.o_servicio as numero_orden, s.fecha_registro as fecha_creacion, s.cliente_id, c.nombre_completo as cliente_nombre,
                   IFNULL(fcs.valor_snapshot, 0.0) as valor_snapshot, 
                   IFNULL(fcs.total_repuestos, 0.0) as total_repuestos, 
                   IFNULL(fcs.total_mano_obra, 0.0) as total_mano_obra, 
                   IFNULL(fcs.estado_comercial_cache, 'SIN_SNAPSHOT') as estado_comercial_cache, 
                   ep.nombre_estado,
                   s.estado_financiero_id,
                   s.estado_fin_fecha_inicio,
                   IFNULL(NULLIF(TRIM(ep_fin.nombre_estado), ''), 'Pendiente Gestión') AS estado_financiero_nombre,
                   IFNULL(NULLIF(TRIM(ep_fin.color), ''), '#9E9E9E') AS estado_financiero_color,
                   IFNULL(NULLIF(TRIM(ep_fin.estado_base_codigo), ''), 'FIN_PENDIENTE') AS estado_financiero_codigo
            FROM servicios s
            LEFT JOIN clientes c ON s.cliente_id = c.id
            LEFT JOIN estados_proceso ep ON s.estado = ep.id
            LEFT JOIN estados_proceso ep_fin ON s.estado_financiero_id = ep_fin.id
            LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
            WHERE ep.estado_base_codigo = 'LEGALIZADO' 
              AND (fcs.estado_comercial_cache IN ('NO_FACTURADO', 'CAUSADO', 'PENDIENTE', 'PENDIENTE_CAUSACION') OR fcs.id IS NULL)
            ORDER BY s.fecha_registro DESC";

    $result = $conn->query($sql);
    $pendientes = $result->fetch_all(MYSQLI_ASSOC);

    sendJsonResponse([
        'success' => true,
        'data' => $pendientes
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
