<?php
require_once 'login/auth_middleware.php';
require_once 'conexion.php';

try {
    $sql = "SELECT s.id, s.o_servicio, s.fecha_registro, s.estado, ep.nombre_estado, ep.estado_base_codigo, 
                   fcs.estado_comercial_cache
            FROM servicios s
            JOIN estados_proceso ep ON s.estado = ep.id
            LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
            ORDER BY s.id DESC LIMIT 20";
    
    $result = $conn->query($sql);
    $data = $result->fetch_all(MYSQLI_ASSOC);
    
    header('Content-Type: application/json');
    echo json_encode(['success' => true, 'data' => $data]);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
}
