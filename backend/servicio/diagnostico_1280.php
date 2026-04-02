<?php
// backend/servicio/diagnostico_1280.php
require_once dirname(__DIR__) . '/conexion.php';

header('Content-Type: application/json; charset=utf-8');

$o_servicio = 1280;
$response = [];

try {
    // 1. Buscar por o_servicio (el número que ve el usuario)
    $sql = "SELECT id, o_servicio, tipo_mantenimiento, centro_costo, fecha_registro, id_equipo, cliente_id, responsable_id 
            FROM servicios 
            WHERE o_servicio = ? OR id = ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ii", $o_servicio, $o_servicio);
    $stmt->execute();
    $result = $stmt->get_result();

    $servicios = [];
    while ($row = $result->fetch_assoc()) {
        $servicios[] = $row;
    }

    $response['servicios_encontrados'] = $servicios;
    $response['total'] = count($servicios);

    // 2. Buscar si hay columnas de registro o empresa que filtren
    $colCheck = $conn->query("SHOW COLUMNS FROM servicios");
    $cols = [];
    while ($c = $colCheck->fetch_assoc())
        $cols[] = $c['Field'];
    $response['columnas_servicios'] = $cols;

} catch (Exception $e) {
    $response['error'] = $e->getMessage();
}

echo json_encode($response, JSON_PRETTY_PRINT);
?>