<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, user-id");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Content-Type: application/json; charset=UTF-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

/**
 * GET /API_Infoapp/inventory/movements/get_movements.php
 * 
 * Endpoint para obtener historial de movimientos de inventario
 * Soporta filtros por item, fechas, tipos, etc.
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

// Solo permitir método GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit();
}

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null)
{
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

try {
    // Incluir archivo de conexión
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }

    // === OBTENER PARÁMETROS DE CONSULTA ===
    $inventory_item_id = isset($_GET['inventory_item_id']) ? intval($_GET['inventory_item_id']) : null;
    $movement_type = isset($_GET['movement_type']) ? trim($_GET['movement_type']) : null;
    $movement_reason = isset($_GET['movement_reason']) ? trim($_GET['movement_reason']) : null;
    $date_from = isset($_GET['date_from']) ? trim($_GET['date_from']) : null;
    $date_to = isset($_GET['date_to']) ? trim($_GET['date_to']) : null;
    $period = isset($_GET['period']) ? trim($_GET['period']) : null;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 50;
    $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'created_at';
    $sort_order = isset($_GET['sort_order']) ? strtoupper(trim($_GET['sort_order'])) : 'DESC';
    $include_item_details = isset($_GET['include_item_details']) ? filter_var($_GET['include_item_details'], FILTER_VALIDATE_BOOLEAN) : true;
    $stats_only = isset($_GET['stats_only']) ? filter_var($_GET['stats_only'], FILTER_VALIDATE_BOOLEAN) : false;

    // Validar limit
    if ($limit < 1 || $limit > 1000) {
        $limit = 50;
    }

    // Validar sort_order
    if (!in_array($sort_order, ['ASC', 'DESC'])) {
        $sort_order = 'DESC';
    }

    // === CONSTRUIR CONSULTA BASE ===
    $where_conditions = [];
    $params = [];
    $param_types = '';

    // Filtro por item específico
    if ($inventory_item_id) {
        $where_conditions[] = "m.inventory_item_id = ?";
        $params[] = $inventory_item_id;
        $param_types .= 'i';
    }

    // Filtro por tipo de movimiento
    if ($movement_type && in_array($movement_type, ['entrada', 'salida', 'ajuste', 'transferencia'])) {
        $where_conditions[] = "m.movement_type = ?";
        $params[] = $movement_type;
        $param_types .= 's';
    }

    // Filtro por razón de movimiento
    if ($movement_reason) {
        $where_conditions[] = "m.movement_reason = ?";
        $params[] = $movement_reason;
        $param_types .= 's';
    }

    // Filtros de fecha
    if ($period) {
        switch ($period) {
            case 'today':
                $where_conditions[] = "DATE(m.created_at) = CURDATE()";
                break;
            case 'week':
                $where_conditions[] = "m.created_at >= DATE_SUB(NOW(), INTERVAL 1 WEEK)";
                break;
            case 'month':
                $where_conditions[] = "m.created_at >= DATE_SUB(NOW(), INTERVAL 1 MONTH)";
                break;
            case 'quarter':
                $where_conditions[] = "m.created_at >= DATE_SUB(NOW(), INTERVAL 3 MONTH)";
                break;
            case 'year':
                $where_conditions[] = "m.created_at >= DATE_SUB(NOW(), INTERVAL 1 YEAR)";
                break;
        }
    } else {
        // Filtros de fecha personalizados
        if ($date_from) {
            $where_conditions[] = "DATE(m.created_at) >= ?";
            $params[] = $date_from;
            $param_types .= 's';
        }
        if ($date_to) {
            $where_conditions[] = "DATE(m.created_at) <= ?";
            $params[] = $date_to;
            $param_types .= 's';
        }
    }

    // === CONSTRUIR CONSULTA FINAL ===
    $where_clause = !empty($where_conditions) ? "WHERE " . implode(" AND ", $where_conditions) : "";

    // === SI SOLO SE REQUIEREN ESTADÍSTICAS ===
    if ($stats_only) {
        $stats_sql = "SELECT 
            COUNT(*) as total_movements,
            SUM(CASE WHEN m.movement_type = 'entrada' THEN 1 ELSE 0 END) as total_entries,
            SUM(CASE WHEN m.movement_type = 'salida' THEN 1 ELSE 0 END) as total_exits,
            SUM(CASE WHEN m.movement_type = 'ajuste' THEN 1 ELSE 0 END) as total_adjustments,
            SUM(m.total_cost) as total_value,
            MAX(m.created_at) as last_movement_date
        FROM inventory_movements m
        $where_clause";

        $stats_stmt = $conn->prepare($stats_sql);

        if (!$stats_stmt) {
            sendErrorResponse(500, 'Error preparando consulta de estadísticas');
        }

        if (!empty($params)) {
            $stats_stmt->bind_param($param_types, ...$params);
        }

        $stats_stmt->execute();
        $stats_result = $stats_stmt->get_result();
        $stats = $stats_result->fetch_assoc();
        $stats_stmt->close();

        // Formatear estadísticas
        $stats['total_movements'] = intval($stats['total_movements']);
        $stats['total_entries'] = intval($stats['total_entries']);
        $stats['total_exits'] = intval($stats['total_exits']);
        $stats['total_adjustments'] = intval($stats['total_adjustments']);
        $stats['total_value'] = floatval($stats['total_value']);

        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Estadísticas obtenidas exitosamente',
            'data' => [
                'summary' => $stats
            ]
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // === OBTENER TOTAL DE REGISTROS (PARA PAGINACIÓN) ===
    $count_sql = "SELECT COUNT(*) as total FROM inventory_movements m $where_clause";
    $count_stmt = $conn->prepare($count_sql);

    if (!$count_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de conteo');
    }

    if (!empty($params)) {
        $count_stmt->bind_param($param_types, ...$params);
    }

    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $total_records = $count_result->fetch_assoc()['total'];
    $count_stmt->close();

    // === CONSTRUIR CONSULTA DE MOVIMIENTOS ===
    if ($include_item_details) {
        $movements_sql = "SELECT 
            m.*,
            i.name as item_name,
            i.sku as item_sku,
            i.unit_of_measure
        FROM inventory_movements m
        LEFT JOIN inventory_items i ON m.inventory_item_id = i.id
        $where_clause
        ORDER BY m.$sort_by $sort_order
        LIMIT $limit OFFSET $offset";
    } else {
        $movements_sql = "SELECT m.*
        FROM inventory_movements m
        $where_clause
        ORDER BY m.$sort_by $sort_order
        LIMIT $limit OFFSET $offset";
    }

    $movements_stmt = $conn->prepare($movements_sql);

    if (!$movements_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de movimientos');
    }

    if (!empty($params)) {
        $movements_stmt->bind_param($param_types, ...$params);
    }

    $movements_stmt->execute();
    $movements_result = $movements_stmt->get_result();

    $movements = [];
    while ($row = $movements_result->fetch_assoc()) {
        // Formatear datos
        $row['id'] = intval($row['id']);
        $row['inventory_item_id'] = intval($row['inventory_item_id']);
        $row['quantity'] = intval($row['quantity']);
        $row['previous_stock'] = intval($row['previous_stock']);
        $row['new_stock'] = intval($row['new_stock']);
        $row['unit_cost'] = floatval($row['unit_cost']);
        $row['total_cost'] = floatval($row['total_cost']);
        $row['reference_id'] = $row['reference_id'] ? intval($row['reference_id']) : null;
        $row['created_by'] = $row['created_by'] ? intval($row['created_by']) : null;

        $movements[] = $row;
    }

    $movements_stmt->close();

    // === CALCULAR PAGINACIÓN ===
    $current_page = floor($offset / $limit) + 1;
    $total_pages = ceil($total_records / $limit);
    $has_next = $offset + $limit < $total_records;
    $has_previous = $offset > 0;

    // === ESTADÍSTICAS RÁPIDAS ===
    $summary = [
        'total_movements' => intval($total_records),
        'shown_movements' => count($movements),
        'page_info' => [
            'current_page' => $current_page,
            'total_pages' => $total_pages,
            'has_next' => $has_next,
            'has_previous' => $has_previous,
            'limit' => $limit,
            'offset' => $offset
        ]
    ];

    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Movimientos obtenidos exitosamente',
        'data' => [
            'movements' => $movements,
            'summary' => $summary,
            'filters_applied' => [
                'inventory_item_id' => $inventory_item_id,
                'movement_type' => $movement_type,
                'movement_reason' => $movement_reason,
                'period' => $period,
                'date_from' => $date_from,
                'date_to' => $date_to
            ]
        ]
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
