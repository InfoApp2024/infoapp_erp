<?php
/**
 * GET /api/inventory/items/check_sku.php
 * Versión con debug para identificar errores 500
 */

// Habilitar reporte de errores para debug
ini_set('display_errors', 1);
ini_set('display_startup_errors', 1);
error_reporting(E_ALL);

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/check_sku.php', 'check_sku');

header('Content-Type: application/json');

try {
    // Debug: Verificar si el archivo de conexión existe
    $conexion_path = '../../conexion.php';
    if (!file_exists($conexion_path)) {
        throw new Exception("Archivo de conexión no encontrado en: " . realpath($conexion_path));
    }
    
    // Incluir archivo de conexión
    require_once $conexion_path;
    
    // Debug: Verificar si la variable $conn existe
    if (!isset($conn)) {
        throw new Exception("Variable de conexión \$conn no está definida en conexion.php");
    }
    
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Debug: Verificar parámetros recibidos
    $debug_info = [
        'GET_params' => $_GET,
        'conexion_path' => realpath($conexion_path),
        'conn_status' => isset($conn) ? 'OK' : 'ERROR'
    ];
    
    // Obtener parámetros
    $sku = isset($_GET['sku']) ? trim($_GET['sku']) : '';
    $exclude_id = isset($_GET['exclude_id']) ? intval($_GET['exclude_id']) : null;
    $suggest_alternatives = isset($_GET['suggest_alternatives']) ? filter_var($_GET['suggest_alternatives'], FILTER_VALIDATE_BOOLEAN) : false;
    
    // Validar que se proporcione SKU
    if (empty($sku)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'SKU es requerido',
            'errors' => ['sku' => 'Debe proporcionar un SKU para verificar'],
            'debug' => $debug_info
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // Validar formato del SKU
    if (strlen($sku) < 3) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'SKU inválido',
            'errors' => ['sku' => 'El SKU debe tener al menos 3 caracteres'],
            'data' => [
                'sku' => $sku,
                'is_available' => false,
                'validation_error' => true
            ],
            'debug' => $debug_info
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // Preparar consulta simple primero
    $check_sql = "SELECT id, sku, name, item_type, is_active, created_at FROM inventory_items WHERE sku = ?";
    
    // Debug: Verificar si la tabla existe
    $table_check = $conn->query("SHOW TABLES LIKE 'inventory_items'");
    if ($table_check->num_rows == 0) {
        throw new Exception("Tabla 'inventory_items' no existe en la base de datos");
    }
    
    $check_stmt = $conn->prepare($check_sql);
    if (!$check_stmt) {
        throw new Exception("Error preparando consulta: " . $conn->error);
    }
    
    $check_stmt->bind_param("s", $sku);
    
    if (!$check_stmt->execute()) {
        throw new Exception("Error ejecutando consulta: " . $check_stmt->error);
    }
    
    $check_result = $check_stmt->get_result();
    $existing_item = $check_result->fetch_assoc();
    
    // Si se proporciona exclude_id, hacer consulta adicional
    if ($exclude_id && $existing_item && $existing_item['id'] == $exclude_id) {
        $existing_item = null; // Excluir este item
    }
    
    // Preparar respuesta
    $is_available = !$existing_item;
    $response_data = [
        'sku' => $sku,
        'is_available' => $is_available,
        'checked_at' => date('Y-m-d H:i:s'),
        'debug' => $debug_info
    ];
    
    // Si el SKU no está disponible
    if (!$is_available) {
        $response_data['existing_item'] = [
            'id' => intval($existing_item['id']),
            'sku' => $existing_item['sku'],
            'name' => $existing_item['name'],
            'item_type' => $existing_item['item_type'],
            'is_active' => boolval($existing_item['is_active']),
            'created_at' => $existing_item['created_at']
        ];
        
        $response_data['conflict_info'] = [
            'message' => boolval($existing_item['is_active']) ? 
                'SKU ya existe en un item activo' : 
                'SKU ya existe en un item inactivo',
            'can_reactivate' => !boolval($existing_item['is_active']),
            'recommendation' => !boolval($existing_item['is_active']) ? 
                'Puede reactivar el item existente o usar un SKU diferente' :
                'Debe usar un SKU diferente'
        ];
    }
    
    // Generar sugerencias solo si se solicita
    if ($suggest_alternatives && (!$is_available || $suggest_alternatives === true)) {
        try {
            $suggestions = generateSimpleSkuSuggestions($conn, $sku, $exclude_id);
            $response_data['suggested_alternatives'] = $suggestions;
        } catch (Exception $e) {
            $response_data['suggestions_error'] = $e->getMessage();
        }
    }
    
    // Validación básica de formato
    $response_data['format_validation'] = [
        'length_ok' => strlen($sku) >= 3 && strlen($sku) <= 50,
        'no_spaces' => strpos($sku, ' ') === false,
        'valid_chars' => preg_match('/^[A-Za-z0-9\-_]+$/', $sku),
        'is_valid' => strlen($sku) >= 3 && strlen($sku) <= 50 && strpos($sku, ' ') === false
    ];
    
    // Determinar código de respuesta HTTP
    $http_code = $is_available ? 200 : 409;
    
    // Respuesta
    http_response_code($http_code);
    echo json_encode([
        'success' => true,
        'message' => $is_available ? 'SKU disponible' : 'SKU no disponible',
        'data' => $response_data
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // Error con información de debug
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()],
        'debug' => [
            'file' => __FILE__,
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString(),
            'get_params' => $_GET ?? 'No disponible'
        ]
    ], JSON_UNESCAPED_UNICODE);
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}

/**
 * Función simplificada para generar sugerencias
 */
function generateSimpleSkuSuggestions($conn, $original_sku, $exclude_id = null) {
    $suggestions = [];
    
    // Solo generar 3 sugerencias simples
    for ($i = 1; $i <= 3; $i++) {
        $suggested_sku = $original_sku . '-' . str_pad($i, 2, '0', STR_PAD_LEFT);
        
        // Verificar disponibilidad
        $sql = "SELECT COUNT(*) as count FROM inventory_items WHERE sku = ?";
        $stmt = $conn->prepare($sql);
        
        if (!$stmt) {
            throw new Exception("Error preparando consulta de sugerencias: " . $conn->error);
        }
        
        $stmt->bind_param("s", $suggested_sku);
        $stmt->execute();
        $result = $stmt->get_result();
        $count = $result->fetch_assoc()['count'];
        
        if ($count == 0) {
            $suggestions[] = [
                'sku' => $suggested_sku,
                'type' => 'numeric_suffix',
                'description' => 'SKU original con sufijo numérico'
            ];
        }
    }
    
    return $suggestions;
}
?>