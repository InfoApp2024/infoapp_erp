<?php
require 'conexion.php';
$sql = "SELECT s.id, s.o_servicio, s.es_finalizado, fcs.estado_comercial_cache 
        FROM servicios s 
        LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id 
        WHERE fcs.estado_comercial_cache IS NOT NULL 
        LIMIT 20";
$result = $conn->query($sql);
$data = [];
while ($row = $result->fetch_assoc()) {
    $data[] = $row;
}
echo json_encode($data, JSON_PRETTY_PRINT);
