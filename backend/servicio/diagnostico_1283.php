<?php
// backend/servicio/diagnostico_1283.php
require_once dirname(__DIR__) . '/conexion.php';

header('Content-Type: application/json');

$id = 1283;
$response = [];

try {
    // 1. Datos crudos de la tabla servicios
    $stmt = $conn->prepare("SELECT id, tipo_mantenimiento, centro_costo FROM servicios WHERE id = ?");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $raw = $stmt->get_result()->fetch_assoc();
    $response['raw_db'] = $raw;

    // 2. Tipos de mantenimiento disponibles
    $types = [];
    $result = $conn->query("SELECT DISTINCT tipo_mantenimiento FROM servicios WHERE tipo_mantenimiento IS NOT NULL AND
tipo_mantenimiento != ''");
    while ($row = $result->fetch_assoc()) {
        $types[] = $row['tipo_mantenimiento'];
    }
    $response['available_types'] = $types;

    // 3. Centros de costo disponibles
    $centers = [];
    $result = $conn->query("SELECT DISTINCT centro_costo FROM servicios WHERE centro_costo IS NOT NULL AND centro_costo !=
''");
    while ($row = $result->fetch_assoc()) {
        $centers[] = $row['centro_costo'];
    }
    $response['available_centers'] = $centers;

} catch (Exception $e) {
    $response['error'] = $e->getMessage();
}

echo json_encode($response, JSON_PRETTY_PRINT);
?>