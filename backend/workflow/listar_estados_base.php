<?php
/**
 * Endpoint: Listar Estados Base del Sistema
 * Propósito: Devolver la lista de estados base disponibles para selección
 * Uso: Dropdown en formularios de creación/edición de estados
 */

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: GET, OPTIONS");
header('Content-Type: application/json; charset=utf-8');

// Manejar petición OPTIONS para CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    // Conexión
    require '../conexion.php';

    // Verificar conexión
    if ($conn->connect_errno) {
        throw new Exception('DB connection error');
    }

    // Configurar charset
    $conn->set_charset('utf8mb4');

    // Consultar estados base ordenados por orden
    $sql = 'SELECT 
        codigo,
        nombre,
        descripcion,
        es_final,
        permite_edicion,
        orden
    FROM estados_base
    ORDER BY orden ASC';

    $result = $conn->query($sql);

    if (!$result) {
        throw new Exception('Query error: ' . $conn->error);
    }

    $estados_base = [];
    while ($row = $result->fetch_assoc()) {
        // Convertir booleanos a int para JSON
        $row['es_final'] = (int) $row['es_final'];
        $row['permite_edicion'] = (int) $row['permite_edicion'];
        $estados_base[] = $row;
    }

    // Devolver respuesta exitosa
    echo json_encode([
        'success' => true,
        'estados_base' => $estados_base,
        'total' => count($estados_base)
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error al obtener estados base: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>