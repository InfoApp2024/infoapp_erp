<?php

/**
 * GET /API_Infoapp/inventory/items/get_items.php
 * 
 * Endpoint para obtener lista de items de inventario con filtros avanzados
 * Usando conexion.php existente del proyecto
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/get_items.php', 'list_items');

header('Content-Type: application/json');

// Incluir tu archivo de conexión existente
require_once '../../conexion.php'; // Desde inventory/ hacia API_Infoapp/

try {
    // Obtener parámetros de la URL
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $category_id = isset($_GET['category_id']) ? intval($_GET['category_id']) : null;
    $item_type = isset($_GET['item_type']) ? trim($_GET['item_type']) : '';
    $supplier_id = isset($_GET['supplier_id']) ? intval($_GET['supplier_id']) : null;
    $low_stock = isset($_GET['low_stock']) ? filter_var($_GET['low_stock'], FILTER_VALIDATE_BOOLEAN) : false;
    $no_stock = isset($_GET['no_stock']) ? filter_var($_GET['no_stock'], FILTER_VALIDATE_BOOLEAN) : false;
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;
    $limit = isset($_GET['limit']) ? max(1, min(100, intval($_GET['limit']))) : 20;
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'name';
    $sort_order = isset($_GET['sort_order']) && strtoupper($_GET['sort_order']) === 'DESC' ? 'DESC' : 'ASC';

    // Campos válidos para ordenamiento
    $valid_sort_fields = [
        'name',
        'sku',
        'item_type',
        'current_stock',
        'minimum_stock',
        'unit_cost',
        'brand',
        'model',
        'created_at',
        'updated_at'
    ];

    if (!in_array($sort_by, $valid_sort_fields)) {
        $sort_by = 'name';
    }

    // Verificar que la conexión esté disponible
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    // Consulta base para contar registros
    $count_sql = "SELECT COUNT(*) as total 
                  FROM inventory_items ii
                  LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
                  LEFT JOIN suppliers s ON ii.supplier_id = s.id
                  WHERE 1=1";

    // Consulta principal
    $sql = "SELECT 
                ii.id,
                ii.sku,
                ii.name,
                ii.description,
                ii.category_id,
                ic.name as category_name,
                ii.item_type,
                ii.brand,
                ii.model,
                ii.part_number,
                ii.current_stock,
                ii.minimum_stock,
                ii.maximum_stock,
                ii.unit_of_measure,
                ii.initial_cost,
                ii.unit_cost,
                ii.average_cost,
                ii.last_cost,
                ii.location,
                ii.shelf,
                ii.bin,
                ii.barcode,
                ii.qr_code,
                ii.supplier_id,
                s.name as supplier_name,
                ii.is_active,
                ii.created_at,
                ii.updated_at,
                -- Calcular valor total del stock
                (ii.current_stock * ii.unit_cost) as stock_value,
                -- Determinar si tiene stock bajo
                CASE 
                    WHEN ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0 THEN 1 
                    ELSE 0 
                END as is_low_stock
            FROM inventory_items ii
            LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
            LEFT JOIN suppliers s ON ii.supplier_id = s.id
            WHERE 1=1";

    // Arrays para parámetros
    $where_conditions = [];
    $count_where_conditions = [];
    $params = [];
    $types = "";

    // Filtro por estado activo/inactivo
    if (!$include_inactive) {
        $where_conditions[] = "ii.is_active = 1";
        $count_where_conditions[] = "ii.is_active = 1";
    }

    // Filtro de búsqueda
    if (!empty($search)) {
        $search_condition = "(ii.sku LIKE ? OR ii.name LIKE ? OR ii.description LIKE ? OR ii.brand LIKE ? OR ii.model LIKE ? OR ii.part_number LIKE ?)";
        $where_conditions[] = $search_condition;
        $count_where_conditions[] = $search_condition;

        $search_param = '%' . $search . '%';
        for ($i = 0; $i < 6; $i++) {
            $params[] = $search_param;
            $types .= "s";
        }
    }

    // Filtro por categoría
    if ($category_id) {
        $where_conditions[] = "ii.category_id = ?";
        $count_where_conditions[] = "ii.category_id = ?";
        $params[] = $category_id;
        $types .= "i";
    }

    // Filtro por tipo de item
    if (!empty($item_type)) {
        $where_conditions[] = "ii.item_type = ?";
        $count_where_conditions[] = "ii.item_type = ?";
        $params[] = $item_type;
        $types .= "s";
    }

    // Filtro por proveedor
    if ($supplier_id) {
        $where_conditions[] = "ii.supplier_id = ?";
        $count_where_conditions[] = "ii.supplier_id = ?";
        $params[] = $supplier_id;
        $types .= "i";
    }

    // Filtro por stock bajo
    if ($low_stock) {
        $where_conditions[] = "ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0";
        $count_where_conditions[] = "ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0";
    }

    // Filtro por sin stock
    if ($no_stock) {
        $where_conditions[] = "ii.current_stock = 0";
        $count_where_conditions[] = "ii.current_stock = 0";
    }

    // Construir WHERE clauses
    if (!empty($where_conditions)) {
        $sql .= " AND " . implode(" AND ", $where_conditions);
    }

    if (!empty($count_where_conditions)) {
        $count_sql .= " AND " . implode(" AND ", $count_where_conditions);
    }

    // Ejecutar consulta de conteo
    $count_stmt = $conn->prepare($count_sql);
    if (!empty($params)) {
        $count_stmt->bind_param($types, ...$params);
    }
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $total_records = $count_result->fetch_assoc()['total'];

    // Agregar ordenamiento y límite
    $sql .= " ORDER BY ii.{$sort_by} {$sort_order}";
    $sql .= " LIMIT ? OFFSET ?";

    // Agregar parámetros de límite
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
        // Convertir tipos de datos
        $row['id'] = intval($row['id']);
        $row['current_stock'] = intval($row['current_stock']);
        $row['minimum_stock'] = intval($row['minimum_stock']);
        $row['maximum_stock'] = intval($row['maximum_stock']);
        $row['unit_cost'] = floatval($row['unit_cost']);
        $row['initial_cost'] = floatval($row['initial_cost']);
        $row['average_cost'] = floatval($row['average_cost']);
        $row['last_cost'] = floatval($row['last_cost']);
        $row['stock_value'] = floatval($row['stock_value']);
        $row['is_low_stock'] = boolval($row['is_low_stock']);
        $row['is_active'] = boolval($row['is_active']);

        $items[] = $row;
    }

    // Calcular estadísticas
    $total_stock_value = array_sum(array_column($items, 'stock_value'));
    $low_stock_count = array_sum(array_column($items, 'is_low_stock'));
    $no_stock_count = count(array_filter($items, function ($item) {
        return $item['current_stock'] == 0;
    }));

    // Calcular información de paginación
    $total_pages = ceil($total_records / $limit);
    $current_page = floor($offset / $limit) + 1;

    // Respuesta exitosa
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Items obtenidos exitosamente',
        'data' => [
            'items' => $items,
            'summary' => [
                'total_items' => count($items),
                'total_stock_value' => $total_stock_value,
                'low_stock_items' => $low_stock_count,
                'no_stock_items' => $no_stock_count,
                'active_items' => count(array_filter($items, function ($item) {
                    return $item['is_active'];
                }))
            ]
        ],
        'pagination' => [
            'current_page' => $current_page,
            'total_pages' => $total_pages,
            'total_records' => intval($total_records),
            'limit' => $limit,
            'offset' => $offset,
            'has_next' => $current_page < $total_pages,
            'has_previous' => $current_page > 1
        ],
        'filters_applied' => [
            'search' => $search,
            'category_id' => $category_id,
            'item_type' => $item_type,
            'supplier_id' => $supplier_id,
            'low_stock' => $low_stock,
            'no_stock' => $no_stock,
            'include_inactive' => $include_inactive,
            'sort_by' => $sort_by,
            'sort_order' => $sort_order
        ]
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    // Error general
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
