<?php
/**
 * GET /api/inventory/movements/get_movements.php
 * 
 * Endpoint para obtener historial de movimientos de inventario con filtros avanzados
 * Incluye información de items, usuarios y referencias relacionadas
 * 
 * Filtros disponibles:
 * - inventory_item_id: int (movimientos de un item específico)
 * - movement_type: string (entrada, salida, ajuste, transferencia)
 * - movement_reason: string (compra, venta, uso_servicio, etc.)
 * - reference_type: string (service, purchase, manual, adjustment)
 * - reference_id: int (ID de referencia específica)
 * - created_by: int (usuario que creó el movimiento)
 * - date_from: date (desde fecha)
 * - date_to: date (hasta fecha)
 * - period: string ('today', 'week', 'month', 'quarter', 'year')
 * - min_quantity: int (cantidad mínima)
 * - max_quantity: int (cantidad máxima)
 * - min_value: float (valor mínimo del movimiento)
 * - max_value: float (valor máximo del movimiento)
 * 
 * Parámetros de control:
 * - limit: int (límite de resultados, default: 50, max: 500)
 * - offset: int (desplazamiento, default: 0)
 * - sort_by: string (campo de ordenamiento, default: created_at)
 * - sort_order: string (ASC|DESC, default: DESC)
 * - include_item_details: boolean (incluir detalles del item, default: true)
 * - group_by_item: boolean (agrupar por item, default: false)
 */

require_once '../../backend/login/auth_middleware.php';
$currentUser = requireAuth();

// Incluir archivo de conexión a la base de datos
require_once '../../../config/database.php';

try {
    // Crear conexión a la base de datos
    $database = new Database();
    $db = $database->getConnection();
    
    // === PARÁMETROS DE FILTROS ===
    $filters = [
        'inventory_item_id' => isset($_GET['inventory_item_id']) ? intval($_GET['inventory_item_id']) : null,
        'movement_type' => isset($_GET['movement_type']) ? trim($_GET['movement_type']) : '',
        'movement_reason' => isset($_GET['movement_reason']) ? trim($_GET['movement_reason']) : '',
        'reference_type' => isset($_GET['reference_type']) ? trim($_GET['reference_type']) : '',
        'reference_id' => isset($_GET['reference_id']) ? intval($_GET['reference_id']) : null,
        'created_by' => isset($_GET['created_by']) ? intval($_GET['created_by']) : null,
        'date_from' => isset($_GET['date_from']) ? trim($_GET['date_from']) : '',
        'date_to' => isset($_GET['date_to']) ? trim($_GET['date_to']) : '',
        'period' => isset($_GET['period']) ? trim($_GET['period']) : '',
        'min_quantity' => isset($_GET['min_quantity']) ? intval($_GET['min_quantity']) : null,
        'max_quantity' => isset($_GET['max_quantity']) ? intval($_GET['max_quantity']) : null,
        'min_value' => isset($_GET['min_value']) ? floatval($_GET['min_value']) : null,
        'max_value' => isset($_GET['max_value']) ? floatval($_GET['max_value']) : null
    ];
    
    // === PARÁMETROS DE CONTROL ===
    $limit = isset($_GET['limit']) ? max(1, min(500, intval($_GET['limit']))) : 50;
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'created_at';
    $sort_order = isset($_GET['sort_order']) && strtoupper($_GET['sort_order']) === 'ASC' ? 'ASC' : 'DESC';
    $include_item_details = isset($_GET['include_item_details']) ? filter_var($_GET['include_item_details'], FILTER_VALIDATE_BOOLEAN) : true;
    $group_by_item = isset($_GET['group_by_item']) ? filter_var($_GET['group_by_item'], FILTER_VALIDATE_BOOLEAN) : false;
    
    // Validar campos de ordenamiento
    $valid_sort_fields = [
        'created_at', 'movement_type', 'movement_reason', 'quantity', 
        'unit_cost', 'total_cost', 'new_stock', 'item_name', 'sku'
    ];
    if (!in_array($sort_by, $valid_sort_fields)) {
        $sort_by = 'created_at';
    }
    
    // === MANEJO DE PERÍODOS PREDEFINIDOS ===
    if (!empty($filters['period'])) {
        $period_dates = calculatePeriodDates($filters['period']);
        if ($period_dates) {
            $filters['date_from'] = $period_dates['from'];
            $filters['date_to'] = $period_dates['to'];
        }
    }
    
    // === CONSTRUCCIÓN DE LA CONSULTA BASE ===
    if ($group_by_item) {
        // Consulta agrupada por item
        $base_sql = "SELECT 
                        ii.id as inventory_item_id,
                        ii.sku,
                        ii.name as item_name,
                        ic.name as category_name,
                        COUNT(im.id) as total_movements,
                        SUM(CASE WHEN im.movement_type = 'entrada' THEN im.quantity ELSE 0 END) as total_entries,
                        SUM(CASE WHEN im.movement_type = 'salida' THEN im.quantity ELSE 0 END) as total_exits,
                        SUM(CASE WHEN im.movement_type = 'ajuste' THEN ABS(im.quantity) ELSE 0 END) as total_adjustments,
                        SUM(CASE WHEN im.movement_type = 'entrada' THEN im.total_cost ELSE 0 END) as total_entry_value,
                        SUM(CASE WHEN im.movement_type = 'salida' THEN im.total_cost ELSE 0 END) as total_exit_value,
                        MAX(im.created_at) as last_movement_date,
                        MIN(im.created_at) as first_movement_date,
                        ii.current_stock
                    FROM inventory_movements im
                    INNER JOIN inventory_items ii ON im.inventory_item_id = ii.id";
        
        if ($include_item_details) {
            $base_sql .= " LEFT JOIN inventory_categories ic ON ii.category_id = ic.id";
        }
        
        $count_sql = "SELECT COUNT(DISTINCT im.inventory_item_id) as total
                      FROM inventory_movements im
                      INNER JOIN inventory_items ii ON im.inventory_item_id = ii.id";
    } else {
        // Consulta detallada de movimientos individuales
        $base_sql = "SELECT 
                        im.id,
                        im.inventory_item_id,
                        im.movement_type,
                        im.movement_reason,
                        im.quantity,
                        im.previous_stock,
                        im.new_stock,
                        im.unit_cost,
                        im.total_cost,
                        im.reference_type,
                        im.reference_id,
                        im.notes,
                        im.document_number,
                        im.created_by,
                        im.created_at,
                        -- Calcular cambio neto en el stock
                        (im.new_stock - im.previous_stock) as stock_change";
        
        if ($include_item_details) {
            $base_sql .= ",
                        ii.sku,
                        ii.name as item_name,
                        ii.item_type,
                        ii.unit_of_measure,
                        ic.name as category_name,
                        s.name as supplier_name";
        }
        
        $base_sql .= " FROM inventory_movements im";
        
        if ($include_item_details) {
            $base_sql .= " INNER JOIN inventory_items ii ON im.inventory_item_id = ii.id
                          LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
                          LEFT JOIN suppliers s ON ii.supplier_id = s.id";
        }
        
        $count_sql = "SELECT COUNT(*) as total
                      FROM inventory_movements im";
        
        if ($include_item_details) {
            $count_sql .= " INNER JOIN inventory_items ii ON im.inventory_item_id = ii.id";
        }
    }
    
    // === CONSTRUCCIÓN DE CONDICIONES WHERE ===
    $where_conditions = [];
    $sql_params = [];
    
    // Filtro por item específico
    if ($filters['inventory_item_id']) {
        $where_conditions[] = "im.inventory_item_id = :inventory_item_id";
        $sql_params[':inventory_item_id'] = $filters['inventory_item_id'];
    }
    
    // Filtro por tipo de movimiento
    if (!empty($filters['movement_type'])) {
        $where_conditions[] = "im.movement_type = :movement_type";
        $sql_params[':movement_type'] = $filters['movement_type'];
    }
    
    // Filtro por razón del movimiento
    if (!empty($filters['movement_reason'])) {
        $where_conditions[] = "im.movement_reason = :movement_reason";
        $sql_params[':movement_reason'] = $filters['movement_reason'];
    }
    
    // Filtro por tipo de referencia
    if (!empty($filters['reference_type'])) {
        $where_conditions[] = "im.reference_type = :reference_type";
        $sql_params[':reference_type'] = $filters['reference_type'];
    }
    
    // Filtro por ID de referencia
    if ($filters['reference_id']) {
        $where_conditions[] = "im.reference_id = :reference_id";
        $sql_params[':reference_id'] = $filters['reference_id'];
    }
    
    // Filtro por usuario creador
    if ($filters['created_by']) {
        $where_conditions[] = "im.created_by = :created_by";
        $sql_params[':created_by'] = $filters['created_by'];
    }
    
    // Filtros de fecha
    if (!empty($filters['date_from'])) {
        $where_conditions[] = "im.created_at >= :date_from";
        $sql_params[':date_from'] = $filters['date_from'] . ' 00:00:00';
    }
    if (!empty($filters['date_to'])) {
        $where_conditions[] = "im.created_at <= :date_to";
        $sql_params[':date_to'] = $filters['date_to'] . ' 23:59:59';
    }
    
    // Filtros de cantidad
    if ($filters['min_quantity'] !== null) {
        $where_conditions[] = "ABS(im.quantity) >= :min_quantity";
        $sql_params[':min_quantity'] = $filters['min_quantity'];
    }
    if ($filters['max_quantity'] !== null) {
        $where_conditions[] = "ABS(im.quantity) <= :max_quantity";
        $sql_params[':max_quantity'] = $filters['max_quantity'];
    }
    
    // Filtros de valor
    if ($filters['min_value'] !== null) {
        $where_conditions[] = "im.total_cost >= :min_value";
        $sql_params[':min_value'] = $filters['min_value'];
    }
    if ($filters['max_value'] !== null) {
        $where_conditions[] = "im.total_cost <= :max_value";
        $sql_params[':max_value'] = $filters['max_value'];
    }
    
    // Construir cláusula WHERE
    $where_clause = "";
    if (!empty($where_conditions)) {
        $where_clause = " WHERE " . implode(' AND ', $where_conditions);
    }
    
    // === EJECUTAR CONSULTA DE CONTEO ===
    $final_count_sql = $count_sql . $where_clause;
    $count_stmt = $db->prepare($final_count_sql);
    $count_stmt->execute($sql_params);
    $total_records = $count_stmt->fetch(PDO::FETCH_ASSOC)['total'];
    
    // === CONSTRUIR CONSULTA FINAL CON ORDENAMIENTO ===
    if ($group_by_item) {
        $group_clause = " GROUP BY ii.id, ii.sku, ii.name, ic.name, ii.current_stock";
        $order_clause = " ORDER BY last_movement_date {$sort_order}";
    } else {
        $group_clause = "";
        $order_clause = " ORDER BY im.{$sort_by} {$sort_order}";
    }
    
    $final_sql = $base_sql . $where_clause . $group_clause . $order_clause . " LIMIT :limit OFFSET :offset";
    $sql_params[':limit'] = $limit;
    $sql_params[':offset'] = $offset;
    
    // === EJECUTAR CONSULTA PRINCIPAL ===
    $stmt = $db->prepare($final_sql);
    
    // Bind de parámetros
    foreach ($sql_params as $key => $value) {
        if ($key === ':limit' || $key === ':offset') {
            $stmt->bindValue($key, $value, PDO::PARAM_INT);
        } else {
            $stmt->bindValue($key, $value);
        }
    }
    
    $stmt->execute();
    $movements = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    // === FORMATEAR RESULTADOS ===
    foreach ($movements as &$movement) {
        if ($group_by_item) {
            // Formatear datos agrupados
            $movement['total_movements'] = intval($movement['total_movements']);
            $movement['total_entries'] = intval($movement['total_entries']);
            $movement['total_exits'] = intval($movement['total_exits']);
            $movement['total_adjustments'] = intval($movement['total_adjustments']);
            $movement['total_entry_value'] = floatval($movement['total_entry_value']);
            $movement['total_exit_value'] = floatval($movement['total_exit_value']);
            $movement['current_stock'] = intval($movement['current_stock']);
        } else {
            // Formatear datos individuales
            $movement['quantity'] = intval($movement['quantity']);
            $movement['previous_stock'] = intval($movement['previous_stock']);
            $movement['new_stock'] = intval($movement['new_stock']);
            $movement['stock_change'] = intval($movement['stock_change']);
            $movement['unit_cost'] = floatval($movement['unit_cost']);
            $movement['total_cost'] = floatval($movement['total_cost']);
        }
    }
    
    // === CALCULAR ESTADÍSTICAS ADICIONALES ===
    $summary_stats = null;
    if (!$group_by_item) {
        $summary_stats = calculateMovementsSummary($movements);
    }
    
    // Calcular información de paginación
    $total_pages = ceil($total_records / $limit);
    $current_page = floor($offset / $limit) + 1;
    
    // === RESPUESTA ===
    $response_data = [
        'movements' => $movements,
        'display_mode' => $group_by_item ? 'grouped_by_item' : 'detailed',
        'applied_filters' => array_filter($filters, function($value) {
            return $value !== null && $value !== '';
        })
    ];
    
    if ($summary_stats) {
        $response_data['summary'] = $summary_stats;
    }
    
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Movimientos obtenidos exitosamente',
        'data' => $response_data,
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
    
} catch (PDOException $e) {
    // Error de base de datos
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error de base de datos',
        'errors' => ['database' => 'Error al consultar los movimientos: ' . $e->getMessage()]
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

/**
 * Función para calcular fechas de períodos predefinidos
 */
function calculatePeriodDates($period) {
    $now = new DateTime();
    $from = clone $now;
    $to = clone $now;
    
    switch ($period) {
        case 'today':
            $from->setTime(0, 0, 0);
            $to->setTime(23, 59, 59);
            break;
        case 'week':
            $from->modify('-7 days')->setTime(0, 0, 0);
            break;
        case 'month':
            $from->modify('-30 days')->setTime(0, 0, 0);
            break;
        case 'quarter':
            $from->modify('-3 months')->setTime(0, 0, 0);
            break;
        case 'year':
            $from->modify('-1 year')->setTime(0, 0, 0);
            break;
        default:
            return null;
    }
    
    return [
        'from' => $from->format('Y-m-d'),
        'to' => $to->format('Y-m-d')
    ];
}

/**
 * Función para calcular resumen de movimientos
 */
function calculateMovementsSummary($movements) {
    $summary = [
        'total_movements' => count($movements),
        'entries' => 0,
        'exits' => 0,
        'adjustments' => 0,
        'total_entry_value' => 0,
        'total_exit_value' => 0,
        'net_quantity_change' => 0,
        'average_movement_value' => 0,
        'unique_items' => []
    ];
    
    foreach ($movements as $movement) {
        switch ($movement['movement_type']) {
            case 'entrada':
                $summary['entries']++;
                $summary['total_entry_value'] += $movement['total_cost'];
                break;
            case 'salida':
                $summary['exits']++;
                $summary['total_exit_value'] += $movement['total_cost'];
                break;
            case 'ajuste':
                $summary['adjustments']++;
                break;
        }
        
        $summary['net_quantity_change'] += $movement['stock_change'];
        $summary['unique_items'][$movement['inventory_item_id']] = true;
    }
    
    $summary['unique_items_count'] = count($summary['unique_items']);
    unset($summary['unique_items']);
    
    if ($summary['total_movements'] > 0) {
        $total_value = $summary['total_entry_value'] + $summary['total_exit_value'];
        $summary['average_movement_value'] = $total_value / $summary['total_movements'];
    }
    
    return $summary;
}

/**
 * Ejemplos de uso:
 * 
 * // Todos los movimientos recientes
 * GET /api/inventory/movements/get_movements.php?limit=20
 * 
 * // Movimientos de un item específico
 * GET /api/inventory/movements/get_movements.php?inventory_item_id=1
 * 
 * // Solo entradas del último mes
 * GET /api/inventory/movements/get_movements.php?movement_type=entrada&period=month
 * 
 * // Movimientos por rango de fechas
 * GET /api/inventory/movements/get_movements.php?date_from=2025-01-01&date_to=2025-01-31
 * 
 * // Movimientos de servicios específicos
 * GET /api/inventory/movements/get_movements.php?reference_type=service&movement_reason=uso_servicio
 * 
 * // Vista agrupada por item
 * GET /api/inventory/movements/get_movements.php?group_by_item=true&period=month
 * 
 * // Movimientos de alto valor
 * GET /api/inventory/movements/get_movements.php?min_value=100&sort_by=total_cost&sort_order=DESC
 */
?>