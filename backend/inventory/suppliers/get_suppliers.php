<?php
/**
 * GET /api/inventory/suppliers/get_suppliers.php
 * 
 * Endpoint para obtener todos los proveedores
 * Incluye estadísticas de items asociados a cada proveedor
 * 
 * Parámetros opcionales:
 * - include_inactive: boolean (incluir proveedores inactivos)
 * - search: string (buscar por nombre o contacto)
 * - limit: int (límite de resultados, default: 50)
 * - offset: int (desplazamiento para paginación, default: 0)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde suppliers/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Obtener parámetros de la URL
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $limit = isset($_GET['limit']) ? max(1, min(100, intval($_GET['limit']))) : 50; // Máximo 100
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;
    
    // === CONSTRUIR CONSULTAS BASE ===
    $count_sql = "SELECT COUNT(*) as total 
                  FROM suppliers s 
                  WHERE 1=1";
    
    $sql = "SELECT 
                s.id,
                s.name,
                s.contact_person,
                s.email,
                s.phone,
                s.address,
                s.tax_id,
                s.is_active,
                s.created_at,
                s.updated_at,
                COUNT(ii.id) as items_count,
                COALESCE(SUM(ii.current_stock * ii.unit_cost), 0) as total_inventory_value
            FROM suppliers s
            LEFT JOIN inventory_items ii ON s.id = ii.supplier_id AND ii.is_active = 1
            WHERE 1=1";
    
    // === APLICAR FILTROS ===
    $where_conditions = [];
    $param_types = "";
    $param_values = [];
    
    // Filtro por estado activo/inactivo
    if (!$include_inactive) {
        $where_conditions[] = "s.is_active = 1";
    }
    
    // Filtro de búsqueda
    if (!empty($search)) {
        $where_conditions[] = "(s.name LIKE ? OR s.contact_person LIKE ? OR s.email LIKE ?)";
        $search_param = '%' . $search . '%';
        $param_types .= "sss";
        $param_values[] = $search_param;
        $param_values[] = $search_param;
        $param_values[] = $search_param;
    }
    
    // Construir cláusulas WHERE
    if (!empty($where_conditions)) {
        $where_clause = " AND " . implode(' AND ', $where_conditions);
        $count_sql .= $where_clause;
        $sql .= $where_clause;
    }
    
    // === EJECUTAR CONSULTA DE CONTEO ===
    $count_stmt = $conn->prepare($count_sql);
    
    if (!empty($param_values)) {
        $count_stmt->bind_param($param_types, ...$param_values);
    }
    
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $total_records = $count_result->fetch_assoc()['total'];
    
    // === CONSTRUIR CONSULTA PRINCIPAL ===
    $sql .= " GROUP BY s.id, s.name, s.contact_person, s.email, s.phone, s.address, s.tax_id, s.is_active, s.created_at, s.updated_at";
    $sql .= " ORDER BY s.name ASC";
    $sql .= " LIMIT ? OFFSET ?";
    
    // === EJECUTAR CONSULTA PRINCIPAL ===
    $stmt = $conn->prepare($sql);
    
    // Preparar parámetros para la consulta principal
    $main_param_types = $param_types . "ii"; // Agregar tipos para LIMIT y OFFSET
    $main_param_values = array_merge($param_values, [$limit, $offset]);
    
    if (!empty($main_param_values)) {
        $stmt->bind_param($main_param_types, ...$main_param_values);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $suppliers = [];
    while ($row = $result->fetch_assoc()) {
        // Formatear datos
        $row['id'] = intval($row['id']);
        $row['items_count'] = intval($row['items_count']);
        $row['total_inventory_value'] = floatval($row['total_inventory_value']);
        $row['is_active'] = boolval($row['is_active']);
        
        $suppliers[] = $row;
    }
    
    // === CALCULAR ESTADÍSTICAS DE RESUMEN ===
    $summary = [
        'total_suppliers' => count($suppliers),
        'active_suppliers' => count(array_filter($suppliers, fn($s) => $s['is_active'])),
        'total_items' => array_sum(array_column($suppliers, 'items_count')),
        'total_inventory_value' => array_sum(array_column($suppliers, 'total_inventory_value'))
    ];
    
    // === CALCULAR INFORMACIÓN DE PAGINACIÓN ===
    $total_pages = ceil($total_records / $limit);
    $current_page = floor($offset / $limit) + 1;
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Proveedores obtenidos exitosamente',
        'data' => [
            'suppliers' => $suppliers,
            'summary' => $summary
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
            'include_inactive' => $include_inactive,
            'search' => $search,
            'limit' => $limit,
            'offset' => $offset
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
 * Ejemplos de uso:
 * 
 * // Obtener todos los proveedores activos (por defecto)
 * GET /api/inventory/suppliers/get_suppliers.php
 * 
 * // Incluir proveedores inactivos
 * GET /api/inventory/suppliers/get_suppliers.php?include_inactive=true
 * 
 * // Buscar proveedores por nombre
 * GET /api/inventory/suppliers/get_suppliers.php?search=filtros
 * 
 * // Paginación
 * GET /api/inventory/suppliers/get_suppliers.php?limit=10&offset=20
 * 
 * // Combinando filtros
 * GET /api/inventory/suppliers/get_suppliers.php?search=repuestos&include_inactive=true&limit=25
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Proveedores obtenidos exitosamente",
 *   "data": {
 *     "suppliers": [
 *       {
 *         "id": 1,
 *         "name": "Repuestos SA",
 *         "contact_person": "Juan Pérez",
 *         "email": "juan@repuestos.com",
 *         "phone": "555-1234",
 *         "address": "Calle 123 #45-67",
 *         "tax_id": "900123456-1",
 *         "is_active": true,
 *         "created_at": "2025-01-15 10:30:00",
 *         "updated_at": "2025-01-15 10:30:00",
 *         "items_count": 15,
 *         "total_inventory_value": 2350.75
 *       }
 *     ],
 *     "summary": {
 *       "total_suppliers": 3,
 *       "active_suppliers": 3,
 *       "total_items": 25,
 *       "total_inventory_value": 5420.50
 *     }
 *   },
 *   "pagination": {
 *     "current_page": 1,
 *     "total_pages": 1,
 *     "total_records": 3,
 *     "limit": 50,
 *     "offset": 0,
 *     "has_next": false,
 *     "has_previous": false
 *   },
 *   "filters_applied": {
 *     "include_inactive": false,
 *     "search": "",
 *     "limit": 50,
 *     "offset": 0
 *   }
 * }
 */
?>