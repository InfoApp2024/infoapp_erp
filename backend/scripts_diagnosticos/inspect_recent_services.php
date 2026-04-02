<?php
// inspect_recent_services.php
require 'conexion.php';

echo "--- ULTIMOS 10 SERVICIOS LEGALIZADOS ---\n";
$sql = "SELECT s.id, s.o_servicio, ep.nombre_estado, ep.estado_base_codigo, fcs.id as fcs_id, fcs.estado_comercial_cache 
        FROM servicios s
        JOIN estados_proceso ep ON s.estado = ep.id
        LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
        WHERE ep.estado_base_codigo = 'LEGALIZADO'
        ORDER BY s.id DESC LIMIT 10";

$res = $conn->query($sql);
echo "OT | Estado Base | FCS ID | Estado Comercial\n";
while ($row = $res->fetch_assoc()) {
    echo "{$row['o_servicio']} | {$row['estado_base_codigo']} | " . ($row['fcs_id'] ?? 'MISSING') . " | " . ($row['estado_comercial_cache'] ?? 'NULL') . "\n";
}

$conn->close();
