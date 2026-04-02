<?php
// =====================================================
// 8. obtener_estado_inicial.php (NUEVO - REQUERIDO)
// =====================================================
header("Access-Control-Allow-Origin: *");
header("Content-Type: application/json");
require '../conexion.php';

// Buscar el estado que no tiene transiciones entrantes (estado inicial)
$sql = "SELECT e.* FROM estados_proceso e 
        LEFT JOIN transiciones_estado t ON e.id = t.estado_destino_id 
        WHERE t.estado_destino_id IS NULL 
        LIMIT 1";

$result = $conn->query($sql);

if ($result->num_rows > 0) {
    $estado = $result->fetch_assoc();
    echo json_encode([
        'success' => true,
        'estado' => $estado
    ]);
} else {
    echo json_encode([
        'success' => false,
        'message' => 'No se encontró un estado inicial configurado'
    ]);
}

$conn->close();
