<?php
/**
 * GET /API_Infoapp/inventory/dashboard/get_dashboard_stats.php
 * 
 * Endpoint para obtener estadísticas principales del dashboard de inventario
 * Incluye métricas generales, alertas, tendencias y resúmenes por categoría
 * 
 * Parámetros opcionales:
 * - period: string ('today', 'week', 'month', 'quarter', 'year', default: 'month')
 * - include_charts: boolean (incluir datos para gráficos, default: true)
 * - include_trends: boolean (incluir tendencias de movimientos, default: true)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/dashboard/get_dashboard_stats.php', 'view_dashboard_stats');

header('Content-Type: application/json');

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde dashboard/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Obtener parámetros
    $period = isset($_GET['period']) ? trim($_GET['period']) : 'month';
    $include_charts = isset($_GET['include_charts']) ? filter_var($_GET['include_charts'], FILTER_VALIDATE_BOOLEAN) : true;
    $include_trends = isset($_GET['include_trends']) ? filter_var($_GET['include_trends'], FILTER_VALIDATE_BOOLEAN) : true;
    
    // Validar período
    $valid_periods = ['today', 'week', 'month', 'quarter', 'year'];
    if (!in_array($period, $valid_periods)) {
        $period = 'month';
    }
    
    // Calcular fechas según el período
    $date_condition = "";
    
    switch ($period) {
        case 'today':
            $date_condition = "AND DATE(im.created_at) = CURDATE()";
            break;
        case 'week':
            $date_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)";
            break;
        case 'month':
            $date_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)";
            break;
        case 'quarter':
            $date_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)";
            break;
        case 'year':
            $date_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)";
            break;
    }
    
    // === ESTADÍSTICAS GENERALES DE INVENTARIO ===
    $general_stats_sql = "SELECT 
        COUNT(*) as total_items,
        SUM(CASE WHEN is_active = 1 THEN 1 ELSE 0 END) as active_items,
        SUM(CASE WHEN current_stock = 0 THEN 1 ELSE 0 END) as no_stock_items,
        SUM(CASE WHEN current_stock <= minimum_stock AND minimum_stock > 0 THEN 1 ELSE 0 END) as low_stock_items,
        SUM(current_stock * unit_cost) as total_inventory_value,
        AVG(current_stock) as avg_stock_per_item,
        COUNT(DISTINCT category_id) as total_categories,
        COUNT(DISTINCT supplier_id) as total_suppliers
    FROM inventory_items 
    WHERE is_active = 1";
    
    $general_stmt = $conn->prepare($general_stats_sql);
    $general_stmt->execute();
    $general_result = $general_stmt->get_result();
    $general_stats = $general_result->fetch_assoc();
    
    // Formatear estadísticas generales
    $general_stats['total_items'] = intval($general_stats['total_items']);
    $general_stats['active_items'] = intval($general_stats['active_items']);
    $general_stats['no_stock_items'] = intval($general_stats['no_stock_items']);
    $general_stats['low_stock_items'] = intval($general_stats['low_stock_items']);
    $general_stats['total_inventory_value'] = floatval($general_stats['total_inventory_value']);
    $general_stats['avg_stock_per_item'] = floatval($general_stats['avg_stock_per_item']);
    $general_stats['total_categories'] = intval($general_stats['total_categories']);
    $general_stats['total_suppliers'] = intval($general_stats['total_suppliers']);
    
    // === ESTADÍSTICAS DE MOVIMIENTOS ===
    $movements_stats_sql = "SELECT 
        COUNT(*) as total_movements,
        SUM(CASE WHEN movement_type = 'entrada' THEN quantity ELSE 0 END) as total_entries,
        SUM(CASE WHEN movement_type = 'salida' THEN quantity ELSE 0 END) as total_exits,
        SUM(CASE WHEN movement_type = 'ajuste' THEN ABS(quantity) ELSE 0 END) as total_adjustments,
        SUM(CASE WHEN movement_type = 'entrada' THEN total_cost ELSE 0 END) as total_entry_value,
        SUM(CASE WHEN movement_type = 'salida' THEN total_cost ELSE 0 END) as total_exit_value,
        COUNT(DISTINCT inventory_item_id) as items_with_movements
    FROM inventory_movements im
    WHERE 1=1 {$date_condition}";
    
    $movements_stmt = $conn->prepare($movements_stats_sql);
    $movements_stmt->execute();
    $movements_result = $movements_stmt->get_result();
    $movements_stats = $movements_result->fetch_assoc();
    
    // Formatear estadísticas de movimientos
    $movements_stats['total_movements'] = intval($movements_stats['total_movements']);
    $movements_stats['total_entries'] = intval($movements_stats['total_entries']);
    $movements_stats['total_exits'] = intval($movements_stats['total_exits']);
    $movements_stats['total_adjustments'] = intval($movements_stats['total_adjustments']);
    $movements_stats['total_entry_value'] = floatval($movements_stats['total_entry_value']);
    $movements_stats['total_exit_value'] = floatval($movements_stats['total_exit_value']);
    $movements_stats['items_with_movements'] = intval($movements_stats['items_with_movements']);
    
    // === TOP ITEMS CON STOCK BAJO ===
    $low_stock_sql = "SELECT 
        ii.id, ii.sku, ii.name, ii.current_stock, ii.minimum_stock,
        ic.name as category_name,
        (ii.current_stock * ii.unit_cost) as stock_value
    FROM inventory_items ii
    LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
    WHERE ii.is_active = 1 
    AND ii.current_stock <= ii.minimum_stock 
    AND ii.minimum_stock > 0
    ORDER BY (ii.current_stock / ii.minimum_stock) ASC, ii.current_stock ASC
    LIMIT 10";
    
    $low_stock_stmt = $conn->prepare($low_stock_sql);
    $low_stock_stmt->execute();
    $low_stock_result = $low_stock_stmt->get_result();
    
    $low_stock_items = [];
    while ($row = $low_stock_result->fetch_assoc()) {
        $row['id'] = intval($row['id']);
        $row['current_stock'] = intval($row['current_stock']);
        $row['minimum_stock'] = intval($row['minimum_stock']);
        $row['stock_value'] = floatval($row['stock_value']);
        $low_stock_items[] = $row;
    }
    
    // === TOP ITEMS MÁS UTILIZADOS ===
    $most_used_sql = "SELECT 
        ii.id, ii.sku, ii.name,
        SUM(CASE WHEN im.movement_type = 'salida' THEN im.quantity ELSE 0 END) as total_usage,
        COUNT(CASE WHEN im.movement_type = 'salida' THEN 1 END) as usage_frequency,
        ic.name as category_name
    FROM inventory_items ii
    LEFT JOIN inventory_movements im ON ii.id = im.inventory_item_id {$date_condition}
    LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
    WHERE ii.is_active = 1
    GROUP BY ii.id, ii.sku, ii.name, ic.name
    HAVING total_usage > 0
    ORDER BY total_usage DESC, usage_frequency DESC
    LIMIT 10";
    
    $most_used_stmt = $conn->prepare($most_used_sql);
    $most_used_stmt->execute();
    $most_used_result = $most_used_stmt->get_result();
    
    $most_used_items = [];
    while ($row = $most_used_result->fetch_assoc()) {
        $row['id'] = intval($row['id']);
        $row['total_usage'] = intval($row['total_usage']);
        $row['usage_frequency'] = intval($row['usage_frequency']);
        $most_used_items[] = $row;
    }
    
    // === RESUMEN POR CATEGORÍAS ===
    $categories_summary_sql = "SELECT 
        ic.id, ic.name,
        COUNT(ii.id) as items_count,
        SUM(ii.current_stock) as total_stock,
        SUM(ii.current_stock * ii.unit_cost) as total_value,
        SUM(CASE WHEN ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0 THEN 1 ELSE 0 END) as low_stock_count
    FROM inventory_categories ic
    LEFT JOIN inventory_items ii ON ic.id = ii.category_id AND ii.is_active = 1
    WHERE ic.is_active = 1
    GROUP BY ic.id, ic.name
    HAVING items_count > 0
    ORDER BY total_value DESC";
    
    $categories_stmt = $conn->prepare($categories_summary_sql);
    $categories_stmt->execute();
    $categories_result = $categories_stmt->get_result();
    
    $categories_summary = [];
    while ($row = $categories_result->fetch_assoc()) {
        $row['id'] = intval($row['id']);
        $row['items_count'] = intval($row['items_count']);
        $row['total_stock'] = intval($row['total_stock']);
        $row['total_value'] = floatval($row['total_value']);
        $row['low_stock_count'] = intval($row['low_stock_count']);
        $categories_summary[] = $row;
    }
    
    // === RESUMEN POR TIPOS DE ITEM ===
    $item_types_sql = "SELECT 
        item_type,
        COUNT(*) as items_count,
        SUM(current_stock) as total_stock,
        SUM(current_stock * unit_cost) as total_value,
        AVG(unit_cost) as avg_unit_cost
    FROM inventory_items 
    WHERE is_active = 1
    GROUP BY item_type
    ORDER BY total_value DESC";
    
    $item_types_stmt = $conn->prepare($item_types_sql);
    $item_types_stmt->execute();
    $item_types_result = $item_types_stmt->get_result();
    
    $item_types_summary = [];
    while ($row = $item_types_result->fetch_assoc()) {
        $row['items_count'] = intval($row['items_count']);
        $row['total_stock'] = intval($row['total_stock']);
        $row['total_value'] = floatval($row['total_value']);
        $row['avg_unit_cost'] = floatval($row['avg_unit_cost']);
        $item_types_summary[] = $row;
    }
    
    // Preparar respuesta base
    $response_data = [
        'period' => $period,
        'generated_at' => date('Y-m-d H:i:s'),
        'general_stats' => $general_stats,
        'movements_stats' => $movements_stats,
        'alerts' => [
            'low_stock_items' => $low_stock_items,
            'no_stock_count' => $general_stats['no_stock_items'],
            'low_stock_count' => $general_stats['low_stock_items']
        ],
        'top_lists' => [
            'most_used_items' => $most_used_items,
            'low_stock_items' => $low_stock_items
        ],
        'summaries' => [
            'by_category' => $categories_summary,
            'by_item_type' => $item_types_summary
        ]
    ];
    
    // === DATOS PARA GRÁFICOS ===
    if ($include_charts) {
        // Movimientos por día (últimos 30 días)
        $daily_movements_sql = "SELECT 
            DATE(created_at) as movement_date,
            SUM(CASE WHEN movement_type = 'entrada' THEN quantity ELSE 0 END) as entries,
            SUM(CASE WHEN movement_type = 'salida' THEN quantity ELSE 0 END) as exits,
            COUNT(*) as total_movements
        FROM inventory_movements 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 30 DAY)
        GROUP BY DATE(created_at)
        ORDER BY movement_date ASC";
        
        $daily_stmt = $conn->prepare($daily_movements_sql);
        $daily_stmt->execute();
        $daily_result = $daily_stmt->get_result();
        
        $daily_movements = [];
        while ($row = $daily_result->fetch_assoc()) {
            $row['entries'] = intval($row['entries']);
            $row['exits'] = intval($row['exits']);
            $row['total_movements'] = intval($row['total_movements']);
            $daily_movements[] = $row;
        }
        
        // Distribución de valor por categoría (para gráfico de torta)
        $value_distribution = array_map(function($cat) {
            return [
                'name' => $cat['name'],
                'value' => floatval($cat['total_value']),
                'items_count' => intval($cat['items_count'])
            ];
        }, $categories_summary);
        
        $response_data['charts'] = [
            'daily_movements' => $daily_movements,
            'value_distribution' => $value_distribution,
            'stock_status' => [
                'normal_stock' => $general_stats['active_items'] - $general_stats['low_stock_items'] - $general_stats['no_stock_items'],
                'low_stock' => $general_stats['low_stock_items'],
                'no_stock' => $general_stats['no_stock_items']
            ]
        ];
    }
    
    // === TENDENCIAS ===
    if ($include_trends) {
        // Comparar con período anterior
        $prev_period_condition = "";
        switch ($period) {
            case 'today':
                $prev_period_condition = "AND DATE(im.created_at) = DATE_SUB(CURDATE(), INTERVAL 1 DAY)";
                break;
            case 'week':
                $prev_period_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 14 DAY) AND im.created_at < DATE_SUB(NOW(), INTERVAL 7 DAY)";
                break;
            case 'month':
                $prev_period_condition = "AND im.created_at >= DATE_SUB(NOW(), INTERVAL 60 DAY) AND im.created_at < DATE_SUB(NOW(), INTERVAL 30 DAY)";
                break;
        }
        
        if (!empty($prev_period_condition)) {
            $prev_movements_sql = str_replace($date_condition, $prev_period_condition, $movements_stats_sql);
            $prev_stmt = $conn->prepare($prev_movements_sql);
            $prev_stmt->execute();
            $prev_result = $prev_stmt->get_result();
            $prev_movements = $prev_result->fetch_assoc();
            
            // Calcular porcentajes de cambio
            $trends = [
                'movements_change' => calculatePercentageChange(
                    intval($prev_movements['total_movements']), 
                    $movements_stats['total_movements']
                ),
                'entries_change' => calculatePercentageChange(
                    intval($prev_movements['total_entries']), 
                    $movements_stats['total_entries']
                ),
                'exits_change' => calculatePercentageChange(
                    intval($prev_movements['total_exits']), 
                    $movements_stats['total_exits']
                ),
                'value_change' => calculatePercentageChange(
                    floatval($prev_movements['total_entry_value']), 
                    $movements_stats['total_entry_value']
                )
            ];
            
            $response_data['trends'] = $trends;
        }
    }
    
    // Respuesta exitosa
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Estadísticas del dashboard obtenidas exitosamente',
        'data' => $response_data
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
 * Función para calcular porcentaje de cambio
 */
function calculatePercentageChange($old_value, $new_value) {
    if ($old_value == 0) {
        return $new_value > 0 ? 100 : 0;
    }
    return round((($new_value - $old_value) / $old_value) * 100, 2);
}

/**
 * Ejemplos de uso:
 * 
 * GET /API_Infoapp/inventory/dashboard/get_dashboard_stats.php
 * GET /API_Infoapp/inventory/dashboard/get_dashboard_stats.php?period=week
 * GET /API_Infoapp/inventory/dashboard/get_dashboard_stats.php?period=month&include_charts=false
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Estadísticas del dashboard obtenidas exitosamente",
 *   "data": {
 *     "period": "month",
 *     "generated_at": "2025-01-15 16:30:00",
 *     "general_stats": {
 *       "total_items": 45,
 *       "active_items": 43,
 *       "no_stock_items": 3,
 *       "low_stock_items": 8,
 *       "total_inventory_value": 25340.75,
 *       "avg_stock_per_item": 15.2,
 *       "total_categories": 6,
 *       "total_suppliers": 8
 *     },
 *     "movements_stats": {
 *       "total_movements": 156,
 *       "total_entries": 89,
 *       "total_exits": 67,
 *       "total_adjustments": 0,
 *       "total_entry_value": 15230.50,
 *       "total_exit_value": 8945.25,
 *       "items_with_movements": 32
 *     },
 *     "alerts": {
 *       "low_stock_items": [
 *         {
 *           "id": 1,
 *           "sku": "REP001",
 *           "name": "Filtro de Aceite",
 *           "current_stock": 3,
 *           "minimum_stock": 5,
 *           "category_name": "Repuestos Mecánicos",
 *           "stock_value": 46.50
 *         }
 *       ],
 *       "no_stock_count": 3,
 *       "low_stock_count": 8
 *     },
 *     "charts": {
 *       "daily_movements": [
 *         {
 *           "movement_date": "2025-01-14",
 *           "entries": 15,
 *           "exits": 12,
 *           "total_movements": 27
 *         }
 *       ],
 *       "value_distribution": [
 *         {
 *           "name": "Repuestos Mecánicos",
 *           "value": 12500.00,
 *           "items_count": 18
 *         }
 *       ],
 *       "stock_status": {
 *         "normal_stock": 32,
 *         "low_stock": 8,
 *         "no_stock": 3
 *       }
 *     },
 *     "trends": {
 *       "movements_change": 15.5,
 *       "entries_change": 8.2,
 *       "exits_change": 22.1,
 *       "value_change": 12.8
 *     }
 *   }
 * }
 */
?>