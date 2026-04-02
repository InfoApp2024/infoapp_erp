<?php
/**
 * GET /API_Infoapp/staff/departments/get_departments.php
 * 
 * Endpoint para obtener lista de departamentos
 * Incluye información de empleados por departamento y manager
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
        'departments' => false,
        'staff' => false,
        'positions' => false
    ];
    
    foreach ($tables_check as $table => $exists) {
        $check_result = $conn->query("SHOW TABLES LIKE '{$table}'");
        $tables_check[$table] = ($check_result && $check_result->num_rows > 0);
    }
    
    // ✅ SI NO EXISTE LA TABLA DEPARTMENTS, CREARLA
    if (!$tables_check['departments']) {
        $create_departments_sql = "CREATE TABLE IF NOT EXISTS departments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            name VARCHAR(100) NOT NULL,
            description TEXT,
            manager_id INT NULL,
            is_active BOOLEAN DEFAULT TRUE,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            deleted_at TIMESTAMP NULL,
            INDEX idx_name (name),
            INDEX idx_manager (manager_id),
            INDEX idx_active (is_active)
        ) ENGINE=InnoDB CHARACTER SET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
        
        if (!$conn->query($create_departments_sql)) {
            sendErrorResponse(500, 'Error creando tabla departments: ' . $conn->error);
        }
        
        // ✅ INSERTAR DEPARTAMENTOS BÁSICOS
        $default_departments = [
            ['Administración', 'Departamento administrativo general'],
            ['Recursos Humanos', 'Gestión del talento humano'],
            ['Tecnología', 'Departamento de sistemas y tecnología'],
            ['Operaciones', 'Operaciones y producción'],
            ['Ventas', 'Equipo comercial y ventas'],
            ['General', 'Departamento general para empleados sin asignar']
        ];
        
        $insert_dept_sql = "INSERT INTO departments (name, description) VALUES (?, ?)";
        $insert_stmt = $conn->prepare($insert_dept_sql);
        
        if ($insert_stmt) {
            foreach ($default_departments as $dept) {
                $insert_stmt->bind_param("ss", $dept[0], $dept[1]);
                $insert_stmt->execute();
            }
            $insert_stmt->close();
        }
        
        $tables_check['departments'] = true;
    }
    
    // === OBTENER PARÁMETROS DE CONSULTA ===
    $include_inactive = isset($_GET['include_inactive']) && ($_GET['include_inactive'] === 'true' || $_GET['include_inactive'] === '1');
    $include_stats = isset($_GET['include_stats']) && ($_GET['include_stats'] === 'true' || $_GET['include_stats'] === '1');
    $include_positions = isset($_GET['include_positions']) && ($_GET['include_positions'] === 'true' || $_GET['include_positions'] === '1');
    $manager_only = isset($_GET['manager_only']) && ($_GET['manager_only'] === 'true' || $_GET['manager_only'] === '1');
    
    // === CONSTRUIR CONSULTA BASE ===
    if ($tables_check['staff']) {
        // Con tabla staff disponible
        $base_sql = "SELECT 
            d.id,
            d.name,
            d.description,
            d.manager_id,
            d.is_active,
            d.created_at,
            d.updated_at,
            CASE 
                WHEN m.id IS NOT NULL THEN CONCAT(m.first_name, ' ', m.last_name)
                ELSE NULL
            END as manager_name,
            CASE 
                WHEN m.id IS NOT NULL THEN m.email
                ELSE NULL
            END as manager_email,
            CASE 
                WHEN m.id IS NOT NULL THEN m.photo_url
                ELSE NULL
            END as manager_photo
        FROM departments d
        LEFT JOIN staff m ON d.manager_id = m.id AND m.deleted_at IS NULL";
    } else {
        // Sin tabla staff - consulta simplificada
        $base_sql = "SELECT 
            d.id,
            d.name,
            d.description,
            d.manager_id,
            d.is_active,
            d.created_at,
            d.updated_at,
            NULL as manager_name,
            NULL as manager_email,
            NULL as manager_photo
        FROM departments d";
    }
    
    // === APLICAR FILTROS ===
    $where_conditions = [];
    
    if (!$include_inactive) {
        $where_conditions[] = "d.is_active = 1";
    }
    
    // Solo filtrar por manager si la tabla staff existe
    if ($manager_only && $tables_check['staff']) {
        $where_conditions[] = "d.manager_id IS NOT NULL";
    }
    
    // Excluir eliminados
    $where_conditions[] = "d.deleted_at IS NULL";
    
    if (!empty($where_conditions)) {
        $base_sql .= " WHERE " . implode(" AND ", $where_conditions);
    }
    
    // === ORDENAMIENTO ===
    $base_sql .= " ORDER BY d.name ASC";
    
    // === EJECUTAR CONSULTA PRINCIPAL ===
    $main_result = $conn->query($base_sql);
    
    if (!$main_result) {
        sendErrorResponse(500, 'Error ejecutando consulta principal: ' . $conn->error);
    }
    
    $departments = [];
    
    while ($row = $main_result->fetch_assoc()) {
        // Formatear datos básicos
        $row['id'] = intval($row['id']);
        $row['manager_id'] = $row['manager_id'] ? intval($row['manager_id']) : null;
        $row['is_active'] = boolval($row['is_active']);
        
        // Información del manager
        $row['has_manager'] = !empty($row['manager_id']);
        
        // Inicializar contadores
        $row['total_employees'] = 0;
        $row['active_employees'] = 0;
        $row['inactive_employees'] = 0;
        $row['total_positions'] = 0;
        $row['active_positions'] = 0;
        
        $departments[] = $row;
    }
    
    // === OBTENER ESTADÍSTICAS DE EMPLEADOS POR DEPARTAMENTO ===
    if ($include_stats && !empty($departments) && $tables_check['staff']) {
        $dept_ids = array_column($departments, 'id');
        $ids_placeholder = str_repeat('?,', count($dept_ids) - 1) . '?';
        
        $stats_sql = "SELECT 
            s.department_id,
            COUNT(*) as total_employees,
            COUNT(CASE WHEN s.is_active = 1 THEN 1 END) as active_employees,
            COUNT(CASE WHEN s.is_active = 0 THEN 1 END) as inactive_employees,
            AVG(s.salary) as average_salary,
            MIN(s.salary) as min_salary,
            MAX(s.salary) as max_salary
        FROM staff s 
        WHERE s.department_id IN ({$ids_placeholder}) AND s.deleted_at IS NULL
        GROUP BY s.department_id";
        
        $stats_stmt = $conn->prepare($stats_sql);
        
        if ($stats_stmt) {
            $types = str_repeat('i', count($dept_ids));
            $stats_stmt->bind_param($types, ...$dept_ids);
            
            if ($stats_stmt->execute()) {
                $stats_result = $stats_stmt->get_result();
                $dept_stats = [];
                
                while ($stat_row = $stats_result->fetch_assoc()) {
                    $dept_stats[$stat_row['department_id']] = [
                        'total_employees' => intval($stat_row['total_employees']),
                        'active_employees' => intval($stat_row['active_employees']),
                        'inactive_employees' => intval($stat_row['inactive_employees']),
                        'average_salary' => $stat_row['average_salary'] ? floatval($stat_row['average_salary']) : null,
                        'min_salary' => $stat_row['min_salary'] ? floatval($stat_row['min_salary']) : null,
                        'max_salary' => $stat_row['max_salary'] ? floatval($stat_row['max_salary']) : null
                    ];
                }
                
                // Aplicar estadísticas a departamentos
                foreach ($departments as &$department) {
                    if (isset($dept_stats[$department['id']])) {
                        $department = array_merge($department, $dept_stats[$department['id']]);
                    }
                }
            }
            
            $stats_stmt->close();
        }
    }
    
    // === OBTENER INFORMACIÓN DE POSICIONES POR DEPARTAMENTO ===
    if ($include_positions && !empty($departments) && $tables_check['positions']) {
        $dept_ids = array_column($departments, 'id');
        $ids_placeholder = str_repeat('?,', count($dept_ids) - 1) . '?';
        
        $positions_sql = "SELECT 
            p.department_id,
            COUNT(*) as total_positions,
            COUNT(CASE WHEN p.is_active = 1 THEN 1 END) as active_positions,
            GROUP_CONCAT(
                CASE WHEN p.is_active = 1 
                THEN JSON_OBJECT('id', p.id, 'title', p.title, 'min_salary', p.min_salary, 'max_salary', p.max_salary)
                END
            ) as positions_list
        FROM positions p 
        WHERE p.department_id IN ({$ids_placeholder})
        GROUP BY p.department_id";
        
        $positions_stmt = $conn->prepare($positions_sql);
        
        if ($positions_stmt) {
            $types = str_repeat('i', count($dept_ids));
            $positions_stmt->bind_param($types, ...$dept_ids);
            
            if ($positions_stmt->execute()) {
                $positions_result = $positions_stmt->get_result();
                $dept_positions = [];
                
                while ($pos_row = $positions_result->fetch_assoc()) {
                    $positions_data = [
                        'total_positions' => intval($pos_row['total_positions']),
                        'active_positions' => intval($pos_row['active_positions'])
                    ];
                    
                    // Procesar lista de posiciones si se incluyen
                    if (!empty($pos_row['positions_list'])) {
                        $positions_list = explode(',', $pos_row['positions_list']);
                        $parsed_positions = [];
                        
                        foreach ($positions_list as $pos_json) {
                            if (!empty($pos_json)) {
                                $position = json_decode($pos_json, true);
                                if ($position) {
                                    $position['id'] = intval($position['id']);
                                    $position['min_salary'] = $position['min_salary'] ? floatval($position['min_salary']) : null;
                                    $position['max_salary'] = $position['max_salary'] ? floatval($position['max_salary']) : null;
                                    $parsed_positions[] = $position;
                                }
                            }
                        }
                        
                        $positions_data['positions'] = $parsed_positions;
                    }
                    
                    $dept_positions[$pos_row['department_id']] = $positions_data;
                }
                
                // Aplicar información de posiciones a departamentos
                foreach ($departments as &$department) {
                    if (isset($dept_positions[$department['id']])) {
                        $department = array_merge($department, $dept_positions[$department['id']]);
                    }
                }
            }
            
            $positions_stmt->close();
        }
    }
    
    // === OBTENER ESTADÍSTICAS GENERALES ===
    $general_stats_sql = "SELECT 
        COUNT(*) as total_departments,
        COUNT(CASE WHEN is_active = 1 THEN 1 END) as active_departments,
        COUNT(CASE WHEN is_active = 0 THEN 1 END) as inactive_departments,
        COUNT(CASE WHEN manager_id IS NOT NULL THEN 1 END) as departments_with_manager,
        COUNT(CASE WHEN manager_id IS NULL THEN 1 END) as departments_without_manager
    FROM departments 
    WHERE deleted_at IS NULL";
    
    $general_stats_result = $conn->query($general_stats_sql);
    $general_stats = $general_stats_result ? $general_stats_result->fetch_assoc() : [];
    
    // Formatear estadísticas generales
    if ($general_stats) {
        foreach ($general_stats as $key => $value) {
            $general_stats[$key] = intval($value);
        }
    }
    
    // === INFORMACIÓN ADICIONAL ===
    $response_info = [
        'total_returned' => count($departments),
        'tables_available' => $tables_check,
        'filters_applied' => [
            'include_inactive' => $include_inactive,
            'include_stats' => $include_stats,
            'include_positions' => $include_positions,
            'manager_only' => $manager_only
        ]
    ];
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Lista de departamentos obtenida exitosamente',
        'data' => $departments,
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