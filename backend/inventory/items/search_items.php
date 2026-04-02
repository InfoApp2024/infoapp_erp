<?php
/**
 * GET /api/inventory/items/search_items.php
 * 
 * Endpoint para búsqueda avanzada de items de inventario
 * Permite múltiples filtros combinados y búsqueda de texto completa
 * 
 * Parámetros de búsqueda:
 * - q: string (búsqueda general en múltiples campos)
 * - sku: string (búsqueda específica por SKU)
 * - name: string (búsqueda específica por nombre)
 * - brand: string (búsqueda por marca)
 * - model: string (búsqueda por modelo)
 * - barcode: string (búsqueda por código de barras)
 * 
 * Filtros específicos:
 * - category_ids: string (IDs de categorías separados por coma)
 * - item_types: string (tipos separados por coma)
 * - supplier_ids: string (IDs de proveedores separados por coma)
 * - stock_status: string ('low', 'normal', 'high', 'empty')
 * - price_min: float (precio mínimo)
 * - price_max: float (precio máximo)
 * - stock_min: int (stock mínimo)
 * - stock_max: int (stock máximo)
 * - location: string (ubicación/almacén)
 * - created_after: date (creados después de esta fecha)
 * - created_before: date (creados antes de esta fecha)
 * - is_active: boolean (estado activo/inactivo)
 * 
 * Parámetros de control:
 * - limit: int (límite de resultados, default: 50, max: 200)
 * - offset: int (desplazamiento, default: 0)
 * - sort_by: string (campo de ordenamiento)
 * - sort_order: string (ASC|DESC)
 * - include_inactive: boolean (incluir items inactivos)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/search_items.php', 'search_items');

header('Content-Type: application/json');

// Incluir archivo de conexión
require_once '../../conexion.php';

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    // === PARÁMETROS DE BÚSQUEDA ===
    $search_params = [
        'q' => isset($_GET['q']) ? trim($_GET['q']) : '',
        'sku' => isset($_GET['sku']) ? trim($_GET['sku']) : '',
        'name' => isset($_GET['name']) ? trim($_GET['name']) : '',
        'brand' => isset($_GET['brand']) ? trim($_GET['brand']) : '',
        'model' => isset($_GET['model']) ? trim($_GET['model']) : '',
        'barcode' => isset($_GET['barcode']) ? trim($_GET['barcode']) : '',
        'location' => isset($_GET['location']) ? trim($_GET['location']) : ''
    ];

    // === FILTROS ESPECÍFICOS ===
    $filters = [
        'category_ids' => isset($_GET['category_ids']) ? explode(',', $_GET['category_ids']) : [],
        'item_types' => isset($_GET['item_types']) ? explode(',', $_GET['item_types']) : [],
        'supplier_ids' => isset($_GET['supplier_ids']) ? explode(',', $_GET['supplier_ids']) : [],
        'stock_status' => isset($_GET['stock_status']) ? trim($_GET['stock_status']) : '',
        'price_min' => isset($_GET['price_min']) ? floatval($_GET['price_min']) : null,
        'price_max' => isset($_GET['price_max']) ? floatval($_GET['price_max']) : null,
        'stock_min' => isset($_GET['stock_min']) ? intval($_GET['stock_min']) : null,
        'stock_max' => isset($_GET['stock_max']) ? intval($_GET['stock_max']) : null,
        'created_after' => isset($_GET['created_after']) ? $_GET['created_after'] : '',
        'created_before' => isset($_GET['created_before']) ? $_GET['created_before'] : '',
        'is_active' => isset($_GET['is_active']) ? filter_var($_GET['is_active'], FILTER_VALIDATE_BOOLEAN) : null
    ];

    // === PARÁMETROS DE CONTROL ===
    $limit = isset($_GET['limit']) ? max(1, min(200, intval($_GET['limit']))) : 50;
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'name';
    $sort_order = isset($_GET['sort_order']) && strtoupper($_GET['sort_order']) === 'DESC' ? 'DESC' : 'ASC';
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;

    // Limpiar arrays de filtros
    $filters['category_ids'] = array_filter(array_map('intval', $filters['category_ids']));
    $filters['supplier_ids'] = array_filter(array_map('intval', $filters['supplier_ids']));
    $filters['item_types'] = array_filter(array_map('trim', $filters['item_types']));

    // Validar campos de ordenamiento
    $valid_sort_fields = [
        'name',
        'sku',
        'item_type',
        'brand',
        'model',
        'current_stock',
        'minimum_stock',
        'unit_cost',
        'location',
        'created_at',
        'updated_at'
    ];

    if (!in_array($sort_by, $valid_sort_fields)) {
        $sort_by = 'name';
    }

    // === CONSTRUIR CONSULTA SQL ===
    $sql = "SELECT 
                ii.*,
                ic.name as category_name,
                s.name as supplier_name,
                (ii.current_stock * ii.unit_cost) as stock_value
            FROM inventory_items ii
            LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
            LEFT JOIN suppliers s ON ii.supplier_id = s.id
            WHERE 1=1";
    
    $params = [];
    $types = "";

    // Búsqueda general
    if (!empty($search_params['q'])) {
        $sql .= " AND (ii.name LIKE ? OR ii.sku LIKE ? OR ii.description LIKE ? OR ii.brand LIKE ? OR ii.model LIKE ?)";
        $term = "%" . $search_params['q'] . "%";
        $params = array_merge($params, [$term, $term, $term, $term, $term]);
        $types .= "sssss";
    }

    // Búsquedas específicas
    if (!empty($search_params['sku'])) {
        $sql .= " AND ii.sku LIKE ?";
        $params[] = "%" . $search_params['sku'] . "%";
        $types .= "s";
    }
    if (!empty($search_params['name'])) {
        $sql .= " AND ii.name LIKE ?";
        $params[] = "%" . $search_params['name'] . "%";
        $types .= "s";
    }
    if (!empty($search_params['brand'])) {
        $sql .= " AND ii.brand = ?";
        $params[] = $search_params['brand'];
        $types .= "s";
    }
    if (!empty($search_params['model'])) {
        $sql .= " AND ii.model LIKE ?";
        $params[] = "%" . $search_params['model'] . "%";
        $types .= "s";
    }
    if (!empty($search_params['barcode'])) {
        $sql .= " AND ii.barcode = ?";
        $params[] = $search_params['barcode'];
        $types .= "s";
    }
    if (!empty($search_params['location'])) {
        $sql .= " AND ii.location LIKE ?";
        $params[] = "%" . $search_params['location'] . "%";
        $types .= "s";
    }

    // Filtros de listas
    if (!empty($filters['category_ids'])) {
        $placeholders = implode(',', array_fill(0, count($filters['category_ids']), '?'));
        $sql .= " AND ii.category_id IN ($placeholders)";
        $params = array_merge($params, $filters['category_ids']);
        $types .= str_repeat('i', count($filters['category_ids']));
    }
    if (!empty($filters['supplier_ids'])) {
        $placeholders = implode(',', array_fill(0, count($filters['supplier_ids']), '?'));
        $sql .= " AND ii.supplier_id IN ($placeholders)";
        $params = array_merge($params, $filters['supplier_ids']);
        $types .= str_repeat('i', count($filters['supplier_ids']));
    }
    if (!empty($filters['item_types'])) {
        $placeholders = implode(',', array_fill(0, count($filters['item_types']), '?'));
        $sql .= " AND ii.item_type IN ($placeholders)";
        $params = array_merge($params, $filters['item_types']);
        $types .= str_repeat('s', count($filters['item_types']));
    }

    // Filtros de rango y estado
    if (!is_null($filters['price_min'])) {
        $sql .= " AND ii.unit_cost >= ?";
        $params[] = $filters['price_min'];
        $types .= "d";
    }
    if (!is_null($filters['price_max'])) {
        $sql .= " AND ii.unit_cost <= ?";
        $params[] = $filters['price_max'];
        $types .= "d";
    }
    if (!is_null($filters['stock_min'])) {
        $sql .= " AND ii.current_stock >= ?";
        $params[] = $filters['stock_min'];
        $types .= "i";
    }
    if (!is_null($filters['stock_max'])) {
        $sql .= " AND ii.current_stock <= ?";
        $params[] = $filters['stock_max'];
        $types .= "i";
    }

    // Filtro de estado de stock
    if ($filters['stock_status'] === 'low') {
        $sql .= " AND ii.current_stock <= ii.minimum_stock AND ii.current_stock > 0";
    } elseif ($filters['stock_status'] === 'empty') {
        $sql .= " AND ii.current_stock = 0";
    } elseif ($filters['stock_status'] === 'high') {
        $sql .= " AND ii.current_stock > ii.maximum_stock AND ii.maximum_stock > 0";
    } elseif ($filters['stock_status'] === 'normal') {
        $sql .= " AND ii.current_stock > ii.minimum_stock AND (ii.maximum_stock = 0 OR ii.current_stock <= ii.maximum_stock)";
    }

    // Filtro activo/inactivo
    if (!$include_inactive) {
        $sql .= " AND ii.is_active = 1";
    } elseif (!is_null($filters['is_active'])) {
        $sql .= " AND ii.is_active = ?";
        $params[] = $filters['is_active'] ? 1 : 0;
        $types .= "i";
    }

    // Filtros de fecha
    if (!empty($filters['created_after'])) {
        $sql .= " AND DATE(ii.created_at) >= ?";
        $params[] = $filters['created_after'];
        $types .= "s";
    }
    if (!empty($filters['created_before'])) {
        $sql .= " AND DATE(ii.created_at) <= ?";
        $params[] = $filters['created_before'];
        $types .= "s";
    }

    // Contar total de resultados
    $count_sql = str_replace("ii.*, ic.name as category_name, s.name as supplier_name, (ii.current_stock * ii.unit_cost) as stock_value", "COUNT(*) as total", $sql);
    $stmt_count = $conn->prepare($count_sql);
    if (!empty($params)) {
        $stmt_count->bind_param($types, ...$params);
    }
    $stmt_count->execute();
    $total_results = $stmt_count->get_result()->fetch_assoc()['total'];
    $stmt_count->close();

    // Ordenamiento y paginación
    $sql .= " ORDER BY ii.$sort_by $sort_order LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    // Ejecutar consulta principal
    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $items = [];
    while ($row = $result->fetch_assoc()) {
        $items[] = $row;
    }

    echo json_encode([
        'success' => true,
        'data' => $items,
        'pagination' => [
            'total' => $total_results,
            'limit' => $limit,
            'offset' => $offset,
            'pages' => ceil($total_results / $limit)
        ]
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
