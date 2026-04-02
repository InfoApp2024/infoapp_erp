<?php
/**
 * GET /API_Infoapp/inventory/items/get_unique_brands.php
 * 
 * Endpoint para obtener lista de marcas únicas existentes
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/get_unique_brands.php', 'list_brands');

header('Content-Type: application/json');

require_once '../../conexion.php';

try {
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    $sql = "SELECT DISTINCT brand FROM inventory_items WHERE brand IS NOT NULL AND brand != '' ORDER BY brand ASC";
    $result = $conn->query($sql);

    $brands = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $brands[] = $row['brand'];
        }
    }

    http_response_code(200);
    echo json_encode([
        'success' => true,
        'data' => $brands
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