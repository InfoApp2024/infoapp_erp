<?php
/**
 * GET /API_Infoapp/inventory/dashboard/get_low_stock_items.php
 * 
 * Endpoint para obtener items de inventario con stock bajo o crítico
 * Incluye análisis de prioridad, recomendaciones y proyecciones
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/dashboard/get_low_stock_items.php', 'view_low_stock_items');

header('Content-Type: application/json');

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde dashboard/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // === PARÁMETROS DE FILTROS ===
    $alert_level = isset($_GET['alert_level']) ? trim($_GET['alert_level']) : 'all';
    $category_ids = isset($_GET['category_ids']) ? array_filter(array_map('intval', explode(',', $_GET['category_ids']))) : [];
    $item_types = isset($_GET['item_types']) ? array_filter(array_map('trim', explode(',', $_GET['item_types']))) : [];
    $supplier_ids = isset($_GET['supplier_ids']) ? array_filter(array_map('intval', explode(',', $_GET['supplier_ids']))) : [];
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;
    $min_usage_frequency = isset($_GET['min_usage_frequency']) ? max(0, intval($_GET['min_usage_frequency'])) : 0;
    $days_supply_threshold = isset($_GET['days_supply_threshold']) ? max(1, intval($_GET['days_supply_threshold'])) : 30;
    
    // === PARÁMETROS DE CONTROL ===
    $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 100;
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'priority';
    $sort_order = isset($_GET['sort_order']) ? strtoupper(trim($_GET['sort_order'])) : '';
    $include_projections = isset($_GET['include_projections']) ? filter_var($_GET['include_projections'], FILTER_VALIDATE_BOOLEAN) : true;
    $include_recommendations = isset($_GET['include_recommendations']) ? filter_var($_GET['include_recommendations'], FILTER_VALIDATE_BOOLEAN) : true;
    
    // Validar nivel de alerta
    $valid_alert_levels = ['critical', 'low', 'moderate', 'all'];
    if (!in_array($alert_level, $valid_alert_levels)) {
        $alert_level = 'all';
    }
    
    // Validar campos de ordenamiento
    $valid_sort_fields = ['priority', 'stock_ratio', 'days_until_out', 'last_usage', 'name', 'current_stock'];
    if (!in_array($sort_by, $valid_sort_fields)) {
        $sort_by = 'priority';
    }
    
    // Determinar orden por defecto según el campo
    if (empty($sort_order)) {
        $sort_order = ($sort_by === 'priority') ? 'ASC' : 'DESC';
    }
    
    // === CONSULTA BASE ===
    $base_sql = "SELECT 
                    ii.id,
                    ii.sku,
                    ii.name,
                    ii.description,
                    ii.category_id,
                    ic.name as category_name,
                    ii.item_type,
                    ii.brand,
                    ii.model,
                    ii.current_stock,
                    ii.minimum_stock,
                    ii.maximum_stock,
                    ii.unit_of_measure,
                    ii.unit_cost,
                    ii.average_cost,
                    ii.location,
                    ii.shelf,
                    ii.bin,
                    ii.supplier_id,
                    s.name as supplier_name,
                    s.contact_person as supplier_contact,
                    s.email as supplier_email,
                    s.phone as supplier_phone,
                    ii.is_active,
                    ii.created_at,
                    ii.updated_at,
                    
                    -- Cálculos de stock
                    (ii.current_stock * ii.unit_cost) as stock_value,
                    CASE 
                        WHEN ii.minimum_stock > 0 THEN ROUND((ii.current_stock / ii.minimum_stock) * 100, 2)
                        ELSE 100
                    END as stock_percentage,
                    CASE 
                        WHEN ii.minimum_stock > 0 THEN ROUND(ii.current_stock / ii.minimum_stock, 3)
                        ELSE 1
                    END as stock_ratio
                    
                FROM inventory_items ii
                LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
                LEFT JOIN suppliers s ON ii.supplier_id = s.id
                WHERE 1=1";
    
    // === CONSTRUIR CONDICIONES WHERE ===
    $where_conditions = [];
    $param_types = "";
    $param_values = [];
    
    // Filtro por estado activo
    if (!$include_inactive) {
        $where_conditions[] = "ii.is_active = 1";
    }
    
    // Condición base para stock bajo
    $stock_conditions = [];
    switch ($alert_level) {
        case 'critical':
            $stock_conditions[] = "ii.current_stock = 0";
            break;
        case 'low':
            $stock_conditions[] = "(ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0 AND ii.current_stock > 0)";
            break;
        case 'moderate':
            $stock_conditions[] = "(ii.current_stock <= (ii.minimum_stock * 1.5) AND ii.current_stock > ii.minimum_stock AND ii.minimum_stock > 0)";
            break;
        case 'all':
        default:
            $stock_conditions[] = "(ii.current_stock = 0 OR (ii.current_stock <= (ii.minimum_stock * 1.5) AND ii.minimum_stock > 0))";
            break;
    }
    
    if (!empty($stock_conditions)) {
        $where_conditions[] = "(" . implode(' OR ', $stock_conditions) . ")";
    }
    
    // Filtros por categorías
    if (!empty($category_ids)) {
        $category_placeholders = implode(',', array_fill(0, count($category_ids), '?'));
        $where_conditions[] = "ii.category_id IN ($category_placeholders)";
        $param_types .= str_repeat("i", count($category_ids));
        $param_values = array_merge($param_values, $category_ids);
    }
    
    // Filtros por tipos de items
    if (!empty($item_types)) {
        $type_placeholders = implode(',', array_fill(0, count($item_types), '?'));
        $where_conditions[] = "ii.item_type IN ($type_placeholders)";
        $param_types .= str_repeat("s", count($item_types));
        $param_values = array_merge($param_values, $item_types);
    }
    
    // Filtros por proveedores
    if (!empty($supplier_ids)) {
        $supplier_placeholders = implode(',', array_fill(0, count($supplier_ids), '?'));
        $where_conditions[] = "ii.supplier_id IN ($supplier_placeholders)";
        $param_types .= str_repeat("i", count($supplier_ids));
        $param_values = array_merge($param_values, $supplier_ids);
    }
    
    // Construir cláusula WHERE
    $where_clause = "";
    if (!empty($where_conditions)) {
        $where_clause = " AND " . implode(' AND ', $where_conditions);
    }
    
    // === EJECUTAR CONSULTA DE CONTEO ===
    $count_sql = "SELECT COUNT(*) as total FROM inventory_items ii 
                  LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
                  LEFT JOIN suppliers s ON ii.supplier_id = s.id
                  WHERE 1=1" . $where_clause;
    
    $count_stmt = $conn->prepare($count_sql);
    if (!$count_stmt) {
        throw new Exception("Error preparando consulta de conteo: " . $conn->error);
    }
    
    if (!empty($param_values)) {
        $count_stmt->bind_param($param_types, ...$param_values);
    }
    
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $total_records = $count_result->fetch_assoc()['total'];
    
    // === CONSTRUIR Y EJECUTAR CONSULTA PRINCIPAL ===
    $order_mappings = [
        'priority' => 'stock_ratio ASC, ii.current_stock DESC',
        'stock_ratio' => 'stock_ratio',
        'current_stock' => 'ii.current_stock',
        'name' => 'ii.name'
    ];
    
    $order_clause = " ORDER BY " . ($order_mappings[$sort_by] ?? $order_mappings['priority']) . " " . $sort_order;
    $final_sql = $base_sql . $where_clause . $order_clause . " LIMIT ? OFFSET ?";
    
    $stmt = $conn->prepare($final_sql);
    if (!$stmt) {
        throw new Exception("Error preparando consulta principal: " . $conn->error);
    }
    
    // Agregar parámetros de limit y offset
    $final_param_types = $param_types . "ii";
    $final_param_values = array_merge($param_values, [$limit, $offset]);
    
    if (!empty($final_param_values)) {
        $stmt->bind_param($final_param_types, ...$final_param_values);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $items = [];
    while ($row = $result->fetch_assoc()) {
        // Formatear números
        $row['id'] = intval($row['id']);
        $row['current_stock'] = intval($row['current_stock']);
        $row['minimum_stock'] = intval($row['minimum_stock']);
        $row['maximum_stock'] = intval($row['maximum_stock']);
        $row['unit_cost'] = floatval($row['unit_cost']);
        $row['average_cost'] = floatval($row['average_cost']);
        $row['stock_value'] = floatval($row['stock_value']);
        $row['stock_percentage'] = floatval($row['stock_percentage']);
        $row['stock_ratio'] = floatval($row['stock_ratio']);
        $row['is_active'] = boolval($row['is_active']);
        $row['category_id'] = $row['category_id'] ? intval($row['category_id']) : null;
        $row['supplier_id'] = $row['supplier_id'] ? intval($row['supplier_id']) : null;
        
        // === DETERMINAR NIVEL DE ALERTA ===
        if ($row['current_stock'] == 0) {
            $row['alert_level'] = 'critical';
            $row['alert_message'] = 'Sin stock disponible';
            $row['priority_score'] = 100;
        } elseif ($row['minimum_stock'] > 0 && $row['current_stock'] <= $row['minimum_stock']) {
            $row['alert_level'] = 'low';
            $row['alert_message'] = 'Stock por debajo del mínimo';
            $row['priority_score'] = 75 + (25 * (1 - $row['stock_ratio']));
        } elseif ($row['minimum_stock'] > 0 && $row['current_stock'] <= ($row['minimum_stock'] * 1.5)) {
            $row['alert_level'] = 'moderate';
            $row['alert_message'] = 'Stock moderadamente bajo';
            $row['priority_score'] = 50 + (25 * (1 - $row['stock_ratio']));
        } else {
            $row['alert_level'] = 'normal';
            $row['alert_message'] = 'Stock normal';
            $row['priority_score'] = 25;
        }
        
        $row['priority_score'] = min(100, max(0, $row['priority_score']));
        
        // === PROYECCIONES SIMPLIFICADAS ===
        if ($include_projections) {
            // Estimación simple basada en stock actual vs mínimo
            if ($row['minimum_stock'] > 0 && $row['current_stock'] > 0) {
                $estimated_days = ($row['current_stock'] / $row['minimum_stock']) * 30;
                $row['days_until_out'] = round(max(1, $estimated_days), 1);
                $row['estimated_out_date'] = date('Y-m-d', strtotime("+{$row['days_until_out']} days"));
                $row['is_critical_timeframe'] = $row['days_until_out'] <= $days_supply_threshold;
            } else {
                $row['days_until_out'] = null;
                $row['estimated_out_date'] = null;
                $row['is_critical_timeframe'] = $row['current_stock'] == 0;
            }
        }
        
        // === RECOMENDACIONES SIMPLIFICADAS ===
        if ($include_recommendations) {
            $recommendations = generateSimplePurchaseRecommendations($row);
            $row['recommendations'] = $recommendations;
        }
        
        $items[] = $row;
    }
    
    // === ESTADÍSTICAS GENERALES ===
    $summary_stats = [
        'total_items' => count($items),
        'critical_items' => count(array_filter($items, fn($item) => $item['alert_level'] === 'critical')),
        'low_stock_items' => count(array_filter($items, fn($item) => $item['alert_level'] === 'low')),
        'moderate_items' => count(array_filter($items, fn($item) => $item['alert_level'] === 'moderate')),
        'total_value_at_risk' => array_sum(array_column($items, 'stock_value')),
        'avg_priority_score' => count($items) > 0 ? round(array_sum(array_column($items, 'priority_score')) / count($items), 1) : 0,
        'items_needing_immediate_attention' => count(array_filter($items, fn($item) => $item['priority_score'] >= 80))
    ];
    
    // Calcular información de paginación
    $total_pages = ceil($total_records / $limit);
    $current_page = floor($offset / $limit) + 1;
    
    // === RESPUESTA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Items con stock bajo obtenidos exitosamente',
        'data' => [
            'items' => $items,
            'summary' => $summary_stats,
            'analysis_settings' => [
                'alert_level' => $alert_level,
                'days_supply_threshold' => $days_supply_threshold,
                'min_usage_frequency' => $min_usage_frequency,
                'include_projections' => $include_projections,
                'include_recommendations' => $include_recommendations
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

/**
 * Función simplificada para generar recomendaciones de compra
 */
function generateSimplePurchaseRecommendations($item) {
    $recommendations = [];
    
    // Cantidad recomendada para compra
    $recommended_order_qty = 0;
    if ($item['maximum_stock'] > 0) {
        $recommended_order_qty = $item['maximum_stock'] - $item['current_stock'];
    } elseif ($item['minimum_stock'] > 0) {
        $recommended_order_qty = ($item['minimum_stock'] * 2) - $item['current_stock'];
    } else {
        $recommended_order_qty = 10; // Cantidad por defecto
    }
    
    $recommended_order_qty = max(1, ceil($recommended_order_qty));
    
    $recommendations['suggested_order_quantity'] = $recommended_order_qty;
    $recommendations['estimated_cost'] = $recommended_order_qty * $item['unit_cost'];
    
    // Urgencia
    if ($item['current_stock'] == 0) {
        $recommendations['urgency'] = 'immediate';
        $recommendations['action'] = 'Compra urgente requerida - Sin stock disponible';
    } elseif (isset($item['days_until_out']) && $item['days_until_out'] && $item['days_until_out'] <= 7) {
        $recommendations['urgency'] = 'high';
        $recommendations['action'] = 'Compra prioritaria - Se agotará pronto';
    } elseif (isset($item['days_until_out']) && $item['days_until_out'] && $item['days_until_out'] <= 30) {
        $recommendations['urgency'] = 'medium';
        $recommendations['action'] = 'Programar compra - Stock bajo';
    } else {
        $recommendations['urgency'] = 'low';
        $recommendations['action'] = 'Monitorear - Stock estable';
    }
    
    // Información del proveedor
    if (!empty($item['supplier_name'])) {
        $recommendations['supplier_info'] = [
            'name' => $item['supplier_name'],
            'contact' => $item['supplier_contact'],
            'email' => $item['supplier_email'],
            'phone' => $item['supplier_phone']
        ];
    }
    
    return $recommendations;
}
?>