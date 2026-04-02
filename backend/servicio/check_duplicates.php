<?php
// backend/servicio/check_duplicates.php
require_once dirname(__DIR__) . '/conexion.php';

header('Content-Type: application/json; charset=utf-8');

try {
    // Buscar o_servicio duplicados
    $sql = "SELECT o_servicio, COUNT(*) as cantidad 
            FROM servicios 
            GROUP BY o_servicio 
            HAVING cantidad > 1 
            ORDER BY cantidad DESC 
            LIMIT 50";

    $result = $conn->query($sql);
    $duplicates = [];
    while ($row = $result->fetch_assoc())
        $duplicates[] = $row;

    // Buscar detalles específicos para o_servicio = 1280
    $sql1280 = "SELECT id, o_servicio, tipo_mantenimiento, centro_costo, responsable_id, cliente_id 
                FROM servicios 
                WHERE o_servicio = 1280";
    $res1280 = $conn->query($sql1280);
    $details1280 = [];
    while ($row = $res1280->fetch_assoc())
        $details1280[] = $row;

    echo json_encode([
        'duplicates' => $duplicates,
        'details_1280' => $details1280
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    echo json_encode(['error' => $e->getMessage()]);
}
?>