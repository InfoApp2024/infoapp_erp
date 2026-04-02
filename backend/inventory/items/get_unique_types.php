<?php
/**
 * GET /API_Infoapp/inventory/items/get_unique_types.php
 * 
 * Endpoint para obtener lista de tipos de items únicos existentes
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/get_unique_types.php', 'list_types');

header('Content-Type: application/json');

require_once '../../conexion.php';

try {
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    $sql = "SELECT DISTINCT item_type FROM inventory_items WHERE item_type IS NOT NULL AND item_type != '' ORDER BY item_type ASC";
    $result = $conn->query($sql);

    $types = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $types[] = $row['item_type'];
        }
    }

    // Agregar tipos por defecto si no están presentes (para asegurar consistencia inicial)
    $default_types = ['repuesto', 'insumo', 'herramienta', 'consumible'];
    foreach ($default_types as $default) {
        if (!in_array($default, $types)) {
            $types[] = $default;
        }
    }
    
    // Reordenar alfabéticamente
    sort($types);

    http_response_code(200);
    echo json_encode([
        'success' => true,
        'data' => $types
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
}

if (isset($conn)) {
    $conn->close();
}
?>