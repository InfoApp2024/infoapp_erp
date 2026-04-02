<?php
/**
 * GET /API_Infoapp/staff/positions/get_positions.php
 * 
 * Endpoint para obtener lista de posiciones/cargos
 * Incluye filtros por departamento y estadísticas de empleados por cargo
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, User-ID');

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null) {
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Manejar preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir método GET
if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método GET']);
}

try {
    // ✅ CORREGIDO: Incluir archivo de conexión con ruta correcta
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }
    
    // ✅ VERIFICAR SI LAS TABLAS EXISTEN ANTES DE USARLAS
    $tables_check = [
        'positions' => false,
        'departments' => false,
        'staff' => false
    ];
    
    foreach ($tables_check as $table => $exists) {
        $check_result = $conn->query("SHOW TABLES LIKE '{$table}'");
        $tables_check[$table] = ($check_result && $check_result->num_rows > 0);
    }
    
    // ✅ SI NO EXISTE LA TABLA POSITIONS, CREARLA
    if (!$tables_check['positions']) {
        $create_positions_sql = "CREATE TABLE IF NOT EXISTS positions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            title VARCHAR(100) NOT NULL,
            description TEXT,
            department_id INT NOT NULL,
            min_salary DECIMAL(10,2) NULL,
            max_salary DECIMAL(10,2) NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at TIMESTAMP NULL,
            INDEX idx_title (title),
            INDEX idx_department (department_id),
            INDEX idx_active (is_active),
            INDEX idx_deleted (deleted_at)
        ) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        if (!$conn->query($create_positions_sql)) {
            sendErrorResponse(500, 'Error creando tabla positions: ' . $conn->error);
        }
        
        // ✅ INSERTAR POSICIONES BÁSICAS SI HAY DEPARTAMENTOS
        if ($tables_check['departments']) {
            $default_positions = [
                ['Gerente General', 'Gerencia general de la organización', 1, 8000.00, 12000.00],
                ['Coordinador de RRHH', 'Coordinación de recursos humanos', 2, 4000.00, 6000.00],
                ['Analista de Sistemas', 'Desarrollo y mantenimiento de sistemas', 3, 3500.00, 5500.00],
                ['Supervisor de Operaciones', 'Supervisión de procesos operativos', 4, 3000.00, 4500.00],
                ['Ejecutivo de Ventas', 'Gestión de ventas y clientes', 5, 2500.00, 4000.00],
                ['Asistente Administrativo', 'Apoyo administrativo general', 1, 1500.00, 2500.00]
            ];
            
            $insert_pos_sql = "INSERT INTO positions (title, description, department_id, min_salary, max_salary) VALUES (?, ?, ?, ?, ?)";
            $insert_stmt = $conn->prepare($insert_pos_sql);
            
            if ($insert_stmt) {
                foreach ($default_positions as $pos) {
                    // Verificar si el departamento existe
                    $check_dept = $conn->query("SELECT COUNT(*) as count FROM departments WHERE id = {$pos[2]}");
                    if ($check_dept && $check_dept->fetch_assoc()['count'] > 0) {
                        $insert_stmt->bind_param("ssidd", $pos[0], $pos[1], $pos[2], $pos[3], $pos[4]);
                        $insert_stmt->execute();
                    }
                }
                $insert_stmt->close();
            }
        }
        
        $tables_check['positions'] = true;
    }
    
    // === OBTENER PARÁMETROS DE CONSULTA ===
    $department_id = isset($_GET['department_id']) && is_numeric($_GET['department_id']) ? intval($_GET['department_id']) : null;
    $include_inactive = isset($_GET['include_inactive']) && ($_GET['include_inactive'] === 'true' || $_GET['include_inactive'] === '1');
    $include_stats = isset($_GET['include_stats']) && ($_GET['include_stats'] === 'true' || $_GET['include_stats'] === '1');
    $include_employees = isset($_GET['include_employees']) && ($_GET['include_employees'] === 'true' || $_GET['include_employees'] === '1');
    $salary_range_only = isset($_GET['salary_range_only']) && ($_GET['salary_range_only'] === 'true' || $_GET['salary_range_only'] === '1');
    $with_employees_only = isset($_GET['with_employees_only']) && ($_GET['with_employees_only'] === 'true' || $_GET['with_employees_only'] === '1');
    
    // === VALIDAR DEPARTAMENTO SI SE PROPORCIONA ===
    if ($department_id !== null && $tables_check['departments']) {
        $check_dept_sql = "SELECT COUNT(*) as count FROM departments WHERE id = ? AND is_active = 1 AND deleted_at IS NULL";
        $check_dept_stmt = $conn->prepare($check_dept_sql);
        
        if (!$check_dept_stmt) {
            sendErrorResponse(500, 'Error validando departamento: ' . $conn->error);
        }
        
        $check_dept_stmt->bind_param("i", $department_id);
        $check_dept_stmt->execute();
        $dept_result = $check_dept_stmt->get_result();
        $dept_exists = $dept_result->fetch_assoc()['count'] > 0;
        $check_dept_stmt->close();
        
        if (!$dept_exists) {
            sendErrorResponse(400, 'El departamento especificado no existe o está inactivo');
        }
    }
    
    // === CONSTRUIR CONSULTA BASE ===
    if ($tables_check['departments']) {
        // Con tabla departments disponible
        $base_sql = "SELECT 
            p.id,
            p.title,
            p.description,
            p.department_id,
            p.min_salary,
            p.max_salary,
            p.is_active,
            p.created_at,
            p.updated_at,
            d.name as department_name,
            d.is_active as department_is_active
        FROM positions p
        INNER JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL";
    } else {
        // Sin tabla departments - consulta simplificada
        $base_sql = "SELECT 
            p.id,
            p.title,
            p.description,
            p.department_id,
            p.min_salary,
            p.max_salary,
            p.is_active,
            p.created_at,
            p.updated_at,
            CONCAT('Departamento ', p.department_id) as department_name,
            TRUE as department_is_active
        FROM positions p";
    }
    
    // === APLICAR FILTROS ===
    $where_conditions = [];
    $bind_params = [];
    $bind_types = "";
    
    // Filtro por departamento
    if ($department_id !== null) {
        $where_conditions[] = "p.department_id = ?";
        $bind_params[] = $department_id;
        $bind_types .= "i";
    }
    
    // Filtro por estado activo
    if (!$include_inactive) {
        $where_conditions[] = "p.is_active = 1";
    }
    
    // Filtro solo posiciones con rango salarial definido
    if ($salary_range_only) {
        $where_conditions[] = "p.min_salary IS NOT NULL AND p.max_salary IS NOT NULL";
    }
    
    // Excluir eliminados
    $where_conditions[] = "p.deleted_at IS NULL";
    
    // Agregar condiciones WHERE si existen
    if (!empty($where_conditions)) {
        $base_sql .= " WHERE " . implode(" AND ", $where_conditions);
    }
    
    // === ORDENAMIENTO ===
    if ($tables_check['departments']) {
        $base_sql .= " ORDER BY d.name ASC, p.title ASC";
    } else {
        $base_sql .= " ORDER BY p.department_id ASC, p.title ASC";
    }
    
    // === EJECUTAR CONSULTA PRINCIPAL ===
    $main_stmt = $conn->prepare($base_sql);
    
    if (!$main_stmt) {
        sendErrorResponse(500, 'Error preparando consulta principal: ' . $conn->error);
    }
    
    if (!empty($bind_params)) {
        $main_stmt->bind_param($bind_types, ...$bind_params);
    }
    
    if (!$main_stmt->execute()) {
        sendErrorResponse(500, 'Error ejecutando consulta principal: ' . $main_stmt->error);
    }
    
    $main_result = $main_stmt->get_result();
    $positions = [];
    
    while ($row = $main_result->fetch_assoc()) {
        // Formatear datos básicos
        $row['id'] = intval($row['id']);
        $row['department_id'] = intval($row['department_id']);
        $row['min_salary'] = $row['min_salary'] ? floatval($row['min_salary']) : null;
        $row['max_salary'] = $row['max_salary'] ? floatval($row['max_salary']) : null;
        $row['is_active'] = boolval($row['is_active']);
        $row['department_is_active'] = boolval($row['department_is_active']);
        
        // Información calculada
        $row['has_salary_range'] = !empty($row['min_salary']) && !empty($row['max_salary']);
        $row['salary_range_text'] = null;
        
        if ($row['has_salary_range']) {
            $row['salary_range_text'] = '$' . number_format($row['min_salary'], 2) . ' - $' . number_format($row['max_salary'], 2);
        }
        
        // Inicializar contadores de empleados
        $row['total_employees'] = 0;
        $row['active_employees'] = 0;
        $row['inactive_employees'] = 0;
        $row['employees_in_salary_range'] = 0;
        $row['employees_below_range'] = 0;
        $row['employees_above_range'] = 0;
        $row['employees_without_salary'] = 0;
        
        $positions[] = $row;
    }
    
    $main_stmt->close();
    
    // === OBTENER ESTADÍSTICAS DE EMPLEADOS POR POSICIÓN (solo si tabla staff existe) ===
    if (($include_stats || $include_employees) && !empty($positions) && $tables_check['staff']) {
        $pos_ids = array_column($positions, 'id');
        $ids_placeholder = str_repeat('?,', count($pos_ids) - 1) . '?';
        
        $stats_sql = "SELECT 
            s.position_id,
            COUNT(*) as total_employees,
            COUNT(CASE WHEN s.is_active = 1 THEN 1 END) as active_employees,
            COUNT(CASE WHEN s.is_active = 0 THEN 1 END) as inactive_employees,
            AVG(s.salary) as average_salary,
            MIN(s.salary) as min_employee_salary,
            MAX(s.salary) as max_employee_salary,
            COUNT(CASE WHEN s.salary IS NULL THEN 1 END) as employees_without_salary
        FROM staff s 
        WHERE s.position_id IN ({$ids_placeholder}) AND s.deleted_at IS NULL
        GROUP BY s.position_id";
        
        $stats_stmt = $conn->prepare($stats_sql);
        
        if ($stats_stmt) {
            $types = str_repeat('i', count($pos_ids));
            $stats_stmt->bind_param($types, ...$pos_ids);
            
            if ($stats_stmt->execute()) {
                $stats_result = $stats_stmt->get_result();
                $pos_stats = [];
                
                while ($stat_row = $stats_result->fetch_assoc()) {
                    $pos_stats[$stat_row['position_id']] = [
                        'total_employees' => intval($stat_row['total_employees']),
                        'active_employees' => intval($stat_row['active_employees']),
                        'inactive_employees' => intval($stat_row['inactive_employees']),
                        'average_salary' => $stat_row['average_salary'] ? floatval($stat_row['average_salary']) : null,
                        'min_employee_salary' => $stat_row['min_employee_salary'] ? floatval($stat_row['min_employee_salary']) : null,
                        'max_employee_salary' => $stat_row['max_employee_salary'] ? floatval($stat_row['max_employee_salary']) : null,
                        'employees_without_salary' => intval($stat_row['employees_without_salary'])
                    ];
                }
                
                // Aplicar estadísticas a posiciones
                foreach ($positions as &$position) {
                    if (isset($pos_stats[$position['id']])) {
                        $position = array_merge($position, $pos_stats[$position['id']]);
                    }
                }
            }
            
            $stats_stmt->close();
        }
    }
    
    // === OBTENER ESTADÍSTICAS GENERALES ===
    $general_stats_sql = "SELECT 
        COUNT(*) as total_positions,
        COUNT(CASE WHEN p.is_active = 1 THEN 1 END) as active_positions,
        COUNT(CASE WHEN p.is_active = 0 THEN 1 END) as inactive_positions,
        COUNT(CASE WHEN p.min_salary IS NOT NULL AND p.max_salary IS NOT NULL THEN 1 END) as positions_with_salary_range,
        COUNT(DISTINCT p.department_id) as departments_with_positions,
        AVG(p.min_salary) as average_min_salary,
        AVG(p.max_salary) as average_max_salary
    FROM positions p
    WHERE p.deleted_at IS NULL";
    
    if ($department_id !== null) {
        $general_stats_sql .= " AND p.department_id = " . intval($department_id);
    }
    
    $general_stats_result = $conn->query($general_stats_sql);
    $general_stats = $general_stats_result ? $general_stats_result->fetch_assoc() : [];
    
    // Formatear estadísticas generales
    if ($general_stats) {
        $general_stats['total_positions'] = intval($general_stats['total_positions']);
        $general_stats['active_positions'] = intval($general_stats['active_positions']);
        $general_stats['inactive_positions'] = intval($general_stats['inactive_positions']);
        $general_stats['positions_with_salary_range'] = intval($general_stats['positions_with_salary_range']);
        $general_stats['departments_with_positions'] = intval($general_stats['departments_with_positions']);
        $general_stats['average_min_salary'] = $general_stats['average_min_salary'] ? floatval($general_stats['average_min_salary']) : null;
        $general_stats['average_max_salary'] = $general_stats['average_max_salary'] ? floatval($general_stats['average_max_salary']) : null;
    }
    
    // === INFORMACIÓN ADICIONAL ===
    $response_info = [
        'total_returned' => count($positions),
        'tables_available' => $tables_check,
        'filters_applied' => [
            'department_id' => $department_id,
            'include_inactive' => $include_inactive,
            'include_stats' => $include_stats,
            'include_employees' => $include_employees,
            'salary_range_only' => $salary_range_only,
            'with_employees_only' => $with_employees_only
        ]
    ];
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Lista de posiciones obtenida exitosamente',
        'data' => $positions,
        'general_stats' => $general_stats,
        'info' => $response_info
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
?>