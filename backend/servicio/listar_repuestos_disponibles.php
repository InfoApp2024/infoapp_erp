<?php
require_once '../login/auth_middleware.php';

// Habilitar logs para debugging
error_reporting(E_ALL);
ini_set('log_errors', 1);
$logFile = __DIR__ . '/listar_repuestos.log';
ini_set('error_log', $logFile);

function logDebug($message, $data = null)
{
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] $message";
    if ($data !== null) {
        $logMessage .= " | Data: " . json_encode($data, JSON_UNESCAPED_UNICODE);
    }
    $logMessage .= "\n";

    global $logFile;
    if (isset($logFile)) {
        @file_put_contents($logFile, $logMessage, FILE_APPEND);
    }
}

try {
    logDebug("========== INICIO listar_repuestos_disponibles.php ==========");

    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    logDebug("Usuario autenticado", ['id' => $currentUser['id'], 'usuario' => $currentUser['usuario']]);

    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio_repuestos/listar_repuestos_disponibles.php', 'view_inventory');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';

    // Parámetros con valores por defecto
    $limit = isset($_GET['limit']) ? min(100, max(1, (int)$_GET['limit'])) : 50;
    $offset = isset($_GET['offset']) ? max(0, (int)$_GET['offset']) : 0;
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $categoryId = isset($_GET['category_id']) ? (int)$_GET['category_id'] : null;

    // 🔧 CORRECCIÓN: Hacer item_type opcional (null = todos los tipos)
    $itemType = isset($_GET['item_type']) && !empty($_GET['item_type']) ? trim($_GET['item_type']) : null;

    $supplierId = isset($_GET['supplier_id']) ? (int)$_GET['supplier_id'] : null;

    // 🔧 CORRECCIÓN: Cambiar default de 1 a 0 para incluir items sin stock
    $minStock = isset($_GET['min_stock']) ? max(0, (int)$_GET['min_stock']) : 0;

    $sortBy = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'name';
    $sortOrder = isset($_GET['sort_order']) ? strtoupper(trim($_GET['sort_order'])) : 'ASC';

    logDebug("Parámetros recibidos", [
        'limit' => $limit,
        'offset' => $offset,
        'search' => $search,
        'category_id' => $categoryId,
        'item_type' => $itemType,
        'supplier_id' => $supplierId,
        'min_stock' => $minStock,
        'sort_by' => $sortBy,
        'sort_order' => $sortOrder
    ]);

    // Validar sort_order
    if (!in_array($sortOrder, ['ASC', 'DESC'])) {
        $sortOrder = 'ASC';
    }

    // Validar sort_by - solo campos seguros
    $allowedSortFields = ['name', 'sku', 'current_stock', 'unit_cost', 'brand', 'category_name'];
    if (!in_array($sortBy, $allowedSortFields)) {
        $sortBy = 'name';
    }

    // Construir WHERE clause
    $whereConditions = [
        "i.is_active = 1" // Solo items activos
    ];
    $params = [];
    $types = "";

    // 🔧 CORRECCIÓN: Solo aplicar filtro de stock si min_stock > 0
    if ($minStock > 0) {
        $whereConditions[] = "i.current_stock >= ?";
        $params[] = $minStock;
        $types .= "i";
        logDebug("Filtro de stock aplicado", ['min_stock' => $minStock]);
    }

    // Filtro por tipo de item (por defecto 'repuesto')
    if (!empty($itemType)) {
        $whereConditions[] = "i.item_type = ?";
        $params[] = $itemType;
        $types .= "s";
        logDebug("Filtro de tipo aplicado", ['item_type' => $itemType]);
    }

    // Filtro por búsqueda
    if (!empty($search)) {
        $whereConditions[] = "(
            i.name LIKE ? OR 
            i.sku LIKE ? OR 
            i.description LIKE ? OR
            i.brand LIKE ? OR
            i.model LIKE ? OR
            i.part_number LIKE ? OR
            c.name LIKE ? OR
            s.name LIKE ?
        )";
        $searchTerm = "%$search%";
        $searchParams = array_fill(0, 8, $searchTerm);
        $params = array_merge($params, $searchParams);
        $types .= str_repeat("s", 8);
        logDebug("Filtro de búsqueda aplicado", ['search' => $search]);
    }

    // Filtro por categoría
    if ($categoryId !== null && $categoryId > 0) {
        $whereConditions[] = "i.category_id = ?";
        $params[] = $categoryId;
        $types .= "i";
        logDebug("Filtro de categoría aplicado", ['category_id' => $categoryId]);
    }

    // Filtro por proveedor
    if ($supplierId !== null && $supplierId > 0) {
        $whereConditions[] = "i.supplier_id = ?";
        $params[] = $supplierId;
        $types .= "i";
        logDebug("Filtro de proveedor aplicado", ['supplier_id' => $supplierId]);
    }

    $whereClause = "WHERE " . implode(" AND ", $whereConditions);
    logDebug("WHERE clause construido", ['where' => $whereClause, 'params_count' => count($params)]);

    // QUERY PRINCIPAL - Obtener repuestos disponibles
    $sqlItems = "SELECT 
                i.id,
                i.sku,
                i.name,
                i.description,
                i.category_id,
                i.item_type,
                i.brand,
                i.model,
                i.part_number,
                i.current_stock,
                i.minimum_stock,
                i.maximum_stock,
                i.unit_of_measure,
                i.unit_cost,
                i.average_cost,
                i.last_cost,
                i.location,
                i.shelf,
                i.bin,
                i.barcode,
                i.qr_code,
                i.supplier_id,
                i.is_active,
                i.created_at,
                i.updated_at,
                
                -- Información de categoría
                c.name as category_name,
                
                -- Información de proveedor
                s.name as supplier_name,
                s.contact_person as supplier_contact,
                s.phone as supplier_phone,
                
                -- Campos calculados
                (i.current_stock * i.unit_cost) as stock_value,
                CASE 
                    WHEN i.current_stock <= 0 THEN 'critical'
                    WHEN i.current_stock <= i.minimum_stock THEN 'low'
                    WHEN i.current_stock <= (i.minimum_stock * 1.5) THEN 'moderate'
                    ELSE 'normal'
                END as alert_level,
                CASE 
                    WHEN i.current_stock <= i.minimum_stock THEN 1
                    ELSE 0
                END as is_low_stock
                
            FROM inventory_items i
            LEFT JOIN inventory_categories c ON i.category_id = c.id
            LEFT JOIN suppliers s ON i.supplier_id = s.id
            $whereClause
            ORDER BY i.$sortBy $sortOrder
            LIMIT ? OFFSET ?";

    // QUERY PARA CONTAR TOTAL
    $sqlCount = "SELECT COUNT(*) as total
            FROM inventory_items i
            LEFT JOIN inventory_categories c ON i.category_id = c.id
            LEFT JOIN suppliers s ON i.supplier_id = s.id
            $whereClause";

    logDebug("Query principal construido", ['sql' => substr($sqlItems, 0, 200) . '...']);

    // Ejecutar query de conteo primero para ver el total
    $stmtCount = $conn->prepare($sqlCount);
    if (!empty($params)) {
        $stmtCount->bind_param($types, ...$params);
    }

    if (!$stmtCount->execute()) {
        throw new Exception("Error ejecutando query de conteo: " . $stmtCount->error);
    }

    $resultCount = $stmtCount->get_result();
    $totalRecords = $resultCount->fetch_assoc()['total'];

    logDebug("Query de conteo ejecutado", ['total_records' => $totalRecords]);

    // Ejecutar query principal
    $stmt = $conn->prepare($sqlItems);
    $allParams = array_merge($params, [$limit, $offset]);
    $allTypes = $types . "ii";

    if (!empty($allParams)) {
        $stmt->bind_param($allTypes, ...$allParams);
    }

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query de repuestos: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $items = [];

    logDebug("Query principal ejecutado", ['rows_returned' => $result->num_rows]);

    while ($row = $result->fetch_assoc()) {
        $item = [
            // Campos básicos
            'id' => (int)$row['id'],
            'sku' => $row['sku'],
            'name' => $row['name'],
            'description' => $row['description'],
            'category_id' => $row['category_id'] ? (int)$row['category_id'] : null,
            'category_name' => $row['category_name'],
            'item_type' => $row['item_type'],
            'brand' => $row['brand'],
            'model' => $row['model'],
            'part_number' => $row['part_number'],

            // Stock y medidas
            'current_stock' => (float)$row['current_stock'],
            'minimum_stock' => (float)$row['minimum_stock'],
            'maximum_stock' => (float)$row['maximum_stock'],
            'unit_of_measure' => $row['unit_of_measure'],

            // Costos
            'unit_cost' => (float)$row['unit_cost'],
            'average_cost' => (float)$row['average_cost'],
            'last_cost' => (float)$row['last_cost'],
            'stock_value' => (float)$row['stock_value'],

            // Ubicación
            'location' => $row['location'],
            'shelf' => $row['shelf'],
            'bin' => $row['bin'],
            'full_location' => buildFullLocation($row['location'], $row['shelf'], $row['bin']),

            // Códigos
            'barcode' => $row['barcode'],
            'qr_code' => $row['qr_code'],

            // Proveedor
            'supplier_id' => $row['supplier_id'] ? (int)$row['supplier_id'] : null,
            'supplier_name' => $row['supplier_name'],
            'supplier_contact' => $row['supplier_contact'],
            'supplier_phone' => $row['supplier_phone'],

            // Estados y fechas
            'is_active' => (int)$row['is_active'] === 1,
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],

            // Campos calculados
            'alert_level' => $row['alert_level'],
            'is_low_stock' => (int)$row['is_low_stock'] === 1,
            'stock_percentage' => $row['minimum_stock'] > 0 ?
                round(($row['current_stock'] / $row['minimum_stock']) * 100, 1) : 100,

            // Información visual
            'alert_color' => getAlertColor($row['alert_level']),
            'stock_status_text' => getStockStatusText($row['current_stock'], $row['minimum_stock'], $row['unit_of_measure']),

            // Compatibilidad con el modelo Flutter
            'searchable_text' => buildSearchableText($row)
        ];

        $items[] = $item;
    }

    // Calcular estadísticas adicionales
    $totalPages = ceil($totalRecords / $limit);
    $currentPage = floor($offset / $limit) + 1;

    // Estadísticas de stock
    $lowStockCount = array_sum(array_column($items, 'is_low_stock'));
    $totalValue = array_sum(array_column($items, 'stock_value'));

    logDebug("Estadísticas calculadas", [
        'total_pages' => $totalPages,
        'current_page' => $currentPage,
        'low_stock_count' => $lowStockCount,
        'total_value' => $totalValue
    ]);

    // RESPUESTA
    sendJsonResponse([
        'success' => true,
        'data' => [
            'items' => $items,
            'pagination' => [
                'total_records' => (int)$totalRecords,
                'current_page' => (int)$currentPage,
                'total_pages' => (int)$totalPages,
                'has_next' => $currentPage < $totalPages,
                'has_previous' => $currentPage > 1,
                'items_per_page' => (int)$limit,
                'items_in_page' => count($items)
            ],
            'summary' => [
                'total_items' => (int)$totalRecords,
                'items_in_page' => count($items),
                'low_stock_items' => (int)$lowStockCount,
                'total_stock_value' => round($totalValue, 2),
                'filters_applied' => [
                    'search' => !empty($search) ? $search : null,
                    'category_id' => $categoryId,
                    'item_type' => $itemType,
                    'supplier_id' => $supplierId,
                    'min_stock' => $minStock
                ]
            ]
        ],
        'message' => "Se encontraron $totalRecords repuestos disponibles. Mostrando página $currentPage de $totalPages.",
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);

    logDebug("========== FIN listar_repuestos_disponibles.php ==========");
} catch (Exception $e) {
    logDebug("ERROR CRÍTICO", [
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);
    error_log("Error en listar_repuestos_disponibles.php: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error obteniendo repuestos disponibles: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}

// FUNCIONES AUXILIARES

function buildFullLocation($location, $shelf, $bin)
{
    $parts = [];
    if (!empty($location)) $parts[] = $location;
    if (!empty($shelf)) $parts[] = "Estante: $shelf";
    if (!empty($bin)) $parts[] = "Bin: $bin";
    return !empty($parts) ? implode(' - ', $parts) : 'Ubicación no definida';
}

function getAlertColor($alertLevel)
{
    switch ($alertLevel) {
        case 'critical':
            return '#F44336'; // Rojo
        case 'low':
            return '#FF9800';      // Naranja
        case 'moderate':
            return '#FFC107'; // Amarillo
        default:
            return '#4CAF50';         // Verde
    }
}

function getStockStatusText($currentStock, $minimumStock, $unitOfMeasure)
{
    $stockText = "$currentStock $unitOfMeasure";
    if ($minimumStock > 0 && $currentStock <= $minimumStock) {
        return "$stockText (STOCK BAJO)";
    }
    return $stockText;
}

function buildSearchableText($row)
{
    $parts = [
        $row['sku'] ?? '',
        $row['name'] ?? '',
        $row['description'] ?? '',
        $row['brand'] ?? '',
        $row['model'] ?? '',
        $row['part_number'] ?? '',
        $row['category_name'] ?? '',
        $row['supplier_name'] ?? ''
    ];
    return strtolower(implode(' ', array_filter($parts)));
}
