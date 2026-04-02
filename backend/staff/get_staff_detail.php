<?php
/**
 * GET /API_Infoapp/staff/get_staff_detail.php
 * 
 * Endpoint para obtener el detalle completo de un usuario/empleado específico
 * Reescrito para usar tabla `usuarios` como tabla principal
 * Incluye información relacionada, historial y estadísticas
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

// Función para obtener estadísticas del usuario
function getUserStats($conn, $user_id) {
    $stats = [
        'departments_managed' => 0,
        'total_movements_created' => 0,
        'total_items_created' => 0,
        'total_services_assigned' => 0
    ];
    
    // Departamentos que maneja (si es manager)
    $dept_sql = "SELECT COUNT(*) as count FROM departments WHERE manager_id = ? AND is_active = 1";
    $dept_stmt = $conn->prepare($dept_sql);
    if ($dept_stmt) {
        $dept_stmt->bind_param("i", $user_id);
        $dept_stmt->execute();
        $dept_result = $dept_stmt->get_result();
        $stats['departments_managed'] = $dept_result->fetch_assoc()['count'];
        $dept_stmt->close();
    }
    
    // Movimientos de inventario creados
    $movements_table_check = $conn->query("SHOW TABLES LIKE 'inventory_movements'");
    if ($movements_table_check && $movements_table_check->num_rows > 0) {
        $movements_sql = "SELECT COUNT(*) as count FROM inventory_movements WHERE created_by = ?";
        $movements_stmt = $conn->prepare($movements_sql);
        if ($movements_stmt) {
            $movements_stmt->bind_param("i", $user_id);
            $movements_stmt->execute();
            $movements_result = $movements_stmt->get_result();
            $stats['total_movements_created'] = $movements_result->fetch_assoc()['count'];
            $movements_stmt->close();
        }
    }
    
    // Items de inventario creados
    $items_table_check = $conn->query("SHOW TABLES LIKE 'inventory_items'");
    if ($items_table_check && $items_table_check->num_rows > 0) {
        $items_sql = "SELECT COUNT(*) as count FROM inventory_items WHERE created_by = ?";
        $items_stmt = $conn->prepare($items_sql);
        if ($items_stmt) {
            $items_stmt->bind_param("i", $user_id);
            $items_stmt->execute();
            $items_result = $items_stmt->get_result();
            $stats['total_items_created'] = $items_result->fetch_assoc()['count'];
            $items_stmt->close();
        }
    }
    
    // Servicios asignados
    $services_table_check = $conn->query("SHOW TABLES LIKE 'servicio_staff'");
    if ($services_table_check && $services_table_check->num_rows > 0) {
        $services_sql = "SELECT COUNT(*) as count FROM servicio_staff WHERE staff_id = ?";
        $services_stmt = $conn->prepare($services_sql);
        if ($services_stmt) {
            $services_stmt->bind_param("i", $user_id);
            $services_stmt->execute();
            $services_result = $services_stmt->get_result();
            $stats['total_services_assigned'] = $services_result->fetch_assoc()['count'];
            $services_stmt->close();
        }
    }
    
    return $stats;
}

// Función para calcular completitud del perfil
function calculateProfileCompletion($user_data) {
    $required_fields = [
        'NOMBRE_USER', 'CORREO', 'NUMERO_IDENTIFICACION',
        'ID_DEPARTAMENTO', 'ID_POSICION', 'FECHA_CONTRATACION'
    ];
    
    $optional_fields = [
        'TELEFONO', 'FECHA_NACIMIENTO', 'DIRECCION', 'CONTACTO_EMERGENCIA_NOMBRE',
        'CONTACTO_EMERGENCIA_TELEFONO', 'URL_FOTO'
    ];
    
    $completed_required = 0;
    $completed_optional = 0;
    
    foreach ($required_fields as $field) {
        if (!empty($user_data[$field])) {
            $completed_required++;
        }
    }
    
    foreach ($optional_fields as $field) {
        if (!empty($user_data[$field])) {
            $completed_optional++;
        }
    }
    
    // Peso: 70% campos requeridos, 30% campos opcionales
    $required_percentage = ($completed_required / count($required_fields)) * 0.7;
    $optional_percentage = ($completed_optional / count($optional_fields)) * 0.3;
    
    return round(($required_percentage + $optional_percentage) * 100, 1);
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
    // Incluir archivo de conexión existente
    require_once '../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }
    
    // === OBTENER PARÁMETROS ===
    $user_id = isset($_GET['id']) && is_numeric($_GET['id']) ? intval($_GET['id']) : null;
    $staff_code = isset($_GET['staff_code']) ? trim($_GET['staff_code']) : null;
    $email = isset($_GET['email']) ? trim($_GET['email']) : null;
    
    // Verificar que se proporcione al menos un identificador
    if (!$user_id && !$staff_code && !$email) {
        sendErrorResponse(400, 'Se requiere al menos uno de: id, staff_code, o email');
    }
    
    // === PARÁMETROS OPCIONALES ===
    $include_stats = isset($_GET['include_stats']) ? boolval($_GET['include_stats']) : true;
    $include_relations = isset($_GET['include_relations']) ? boolval($_GET['include_relations']) : true;
    $include_inactive = isset($_GET['include_inactive']) ? boolval($_GET['include_inactive']) : false;
    
    // === CONSTRUIR CONSULTA PRINCIPAL ===
    $main_sql = "SELECT 
        u.id as usuario_id,
        u.ID_CLIENTE,
        u.ID_REGISTRO,
        u.NOMBRE_CLIENTE,
        u.NIT,
        u.CORREO,
        u.NOMBRE_USER,
        u.TIPO_ROL,
        u.CONTRASEÑA,
        u.ESTADO_USER,
        u.CODIGO_STAFF,
        u.TELEFONO,
        u.FECHA_CONTRATACION,
        u.FECHA_NACIMIENTO,
        u.TIPO_IDENTIFICACION,
        u.NUMERO_IDENTIFICACION,
        u.ID_POSICION,
        u.SALARIO,
        u.ID_ESPECIALIDAD,
        u.DIRECCION,
        u.CONTACTO_EMERGENCIA_NOMBRE,
        u.CONTACTO_EMERGENCIA_TELEFONO,
        u.URL_FOTO,
        u.USUARIO_ACTUALIZACION,
        u.FECHA_ELIMINACION,
        u.created_at,
        u.updated_at,
        u.ID_DEPARTAMENTO,
        d.id as dept_id,
        d.name as department_name,
        d.description as department_description,
        d.manager_id as department_manager_id,
        p.id as position_id,
        p.title as position_title,
        p.description as position_description,
        p.min_salary as position_min_salary,
        p.max_salary as position_max_salary,
        manager.id as manager_user_id,
        manager.NOMBRE_USER as manager_name,
        manager.CORREO as manager_email
    FROM usuarios u
    LEFT JOIN departments d ON u.ID_DEPARTAMENTO = d.id
    LEFT JOIN positions p ON u.ID_POSICION = p.id
    LEFT JOIN especialidades e ON u.ID_ESPECIALIDAD = e.id
    LEFT JOIN usuarios manager ON d.manager_id = manager.id
    WHERE ";
    
    // === CONSTRUIR CONDICIÓN WHERE ===
    $params = [];
    $param_types = "";
    
    if ($user_id) {
        $main_sql .= "u.id = ?";
        $params[] = $user_id;
        $param_types .= "i";
    } elseif ($staff_code) {
        $main_sql .= "u.CODIGO_STAFF = ?";
        $params[] = $staff_code;
        $param_types .= "s";
    } elseif ($email) {
        $main_sql .= "u.CORREO = ?";
        $params[] = $email;
        $param_types .= "s";
    }
    
    // Agregar filtro de estado si no se incluyen inactivos
    if (!$include_inactive) {
        $main_sql .= " AND u.ESTADO_USER = 'activo'";
    }
    
    // === EJECUTAR CONSULTA PRINCIPAL ===
    $main_stmt = $conn->prepare($main_sql);
    if (!$main_stmt) {
        sendErrorResponse(500, 'Error preparando consulta: ' . $conn->error);
    }
    
    if (!empty($params)) {
        $refs = array();
        foreach ($params as $key => $value) {
            $refs[$key] = &$params[$key];
        }
        call_user_func_array(array($main_stmt, 'bind_param'), array_merge(array($param_types), $refs));
    }
    
    $main_stmt->execute();
    $main_result = $main_stmt->get_result();
    $user_data = $main_result->fetch_assoc();
    $main_stmt->close();
    
    // === VERIFICAR QUE EL USUARIO EXISTE ===
    if (!$user_data) {
        sendErrorResponse(404, 'Usuario/Empleado no encontrado');
    }
    
    // === FORMATEAR DATOS BÁSICOS ===
    $user_data['id'] = intval($user_data['usuario_id']);
    $user_data['ID_DEPARTAMENTO'] = $user_data['ID_DEPARTAMENTO'] ? intval($user_data['ID_DEPARTAMENTO']) : null;
    $user_data['ID_POSICION'] = $user_data['ID_POSICION'] ? intval($user_data['ID_POSICION']) : null;
    $user_data['SALARIO'] = $user_data['SALARIO'] ? floatval($user_data['SALARIO']) : null;
    $user_data['is_active'] = ($user_data['ESTADO_USER'] === 'activo');
    $user_data['manager_id'] = $user_data['manager_user_id'] ? intval($user_data['manager_user_id']) : null;
    $user_data['position_min_salary'] = $user_data['position_min_salary'] ? floatval($user_data['position_min_salary']) : null;
    $user_data['position_max_salary'] = $user_data['position_max_salary'] ? floatval($user_data['position_max_salary']) : null;
    
    // === AGREGAR CAMPOS CALCULADOS ===
    $user_data['full_name'] = $user_data['NOMBRE_USER'] ?? $user_data['NOMBRE_CLIENTE'] ?? 'Sin nombre';
    $user_data['has_photo'] = !empty($user_data['URL_FOTO']);
    $user_data['has_emergency_contact'] = !empty($user_data['CONTACTO_EMERGENCIA_NOMBRE']);
    
    // Calcular edad si hay fecha de nacimiento
    if ($user_data['FECHA_NACIMIENTO']) {
        try {
            $birth_date = new DateTime($user_data['FECHA_NACIMIENTO']);
            $now = new DateTime();
            $user_data['age'] = $now->diff($birth_date)->y;
        } catch (Exception $e) {
            $user_data['age'] = null;
        }
    } else {
        $user_data['age'] = null;
    }
    
    // Calcular años de servicio
    if ($user_data['FECHA_CONTRATACION']) {
        try {
            $hire_date = new DateTime($user_data['FECHA_CONTRATACION']);
            $now = new DateTime();
            $user_data['years_employed'] = $now->diff($hire_date)->y;
            $user_data['months_employed'] = $now->diff($hire_date)->m + ($user_data['years_employed'] * 12);
        } catch (Exception $e) {
            $user_data['years_employed'] = 0;
            $user_data['months_employed'] = 0;
        }
    } else {
        $user_data['years_employed'] = 0;
        $user_data['months_employed'] = 0;
    }
    
    // Verificar si es manager de departamento
    $user_data['is_department_manager'] = ($user_data['manager_id'] == $user_data['id']);
    
    // Verificar si el salario está en rango de la posición
    $user_data['salary_in_range'] = null;
    if ($user_data['SALARIO'] && $user_data['position_min_salary'] && $user_data['position_max_salary']) {
        $user_data['salary_in_range'] = (
            $user_data['SALARIO'] >= $user_data['position_min_salary'] && 
            $user_data['SALARIO'] <= $user_data['position_max_salary']
        );
    }
    
    // Calcular completitud del perfil
    $user_data['profile_completion'] = calculateProfileCompletion($user_data);
    
    // === INFORMACIÓN DEL MANAGER (SI APLICA) ===
    $manager_info = null;
    if ($user_data['manager_name']) {
        $manager_info = [
            'id' => $user_data['manager_id'],
            'full_name' => $user_data['manager_name'],
            'email' => $user_data['manager_email']
        ];
    }
    
    // === CONSTRUIR RESPUESTA BASE ===
    $response_data = [
        'user' => $user_data,
        'manager' => $manager_info
    ];
    
    // === OBTENER RELACIONES (SI SE SOLICITA) ===
    if ($include_relations) {
        $relations = [];
        
        // Usuarios del mismo departamento
        $colleagues_sql = "SELECT u.id, u.CODIGO_STAFF, u.NOMBRE_USER, u.CORREO, u.ID_POSICION, p.title as position_title
                          FROM usuarios u
                          LEFT JOIN positions p ON u.ID_POSICION = p.id
                          WHERE u.ID_DEPARTAMENTO = ? AND u.id != ? AND u.ESTADO_USER = 'activo'
                          ORDER BY u.NOMBRE_USER
                          LIMIT 10";
        
        $colleagues_stmt = $conn->prepare($colleagues_sql);
        if ($colleagues_stmt) {
            $colleagues_stmt->bind_param("ii", $user_data['ID_DEPARTAMENTO'], $user_data['id']);
            $colleagues_stmt->execute();
            $colleagues_result = $colleagues_stmt->get_result();
            
            $colleagues = [];
            while ($colleague = $colleagues_result->fetch_assoc()) {
                $colleague['id'] = intval($colleague['id']);
                $colleague['ID_POSICION'] = intval($colleague['ID_POSICION']);
                $colleagues[] = $colleague;
            }
            $colleagues_stmt->close();
            
            $relations['colleagues'] = $colleagues;
        }
        
        // Si es manager, obtener sus subordinados
        if ($user_data['is_department_manager']) {
            $subordinates_sql = "SELECT u.id, u.CODIGO_STAFF, u.NOMBRE_USER, u.CORREO, u.ID_POSICION, p.title as position_title
                                FROM usuarios u
                                LEFT JOIN positions p ON u.ID_POSICION = p.id
                                WHERE u.ID_DEPARTAMENTO = ? AND u.id != ? AND u.ESTADO_USER = 'activo'
                                ORDER BY u.NOMBRE_USER";
            
            $subordinates_stmt = $conn->prepare($subordinates_sql);
            if ($subordinates_stmt) {
                $subordinates_stmt->bind_param("ii", $user_data['ID_DEPARTAMENTO'], $user_data['id']);
                $subordinates_stmt->execute();
                $subordinates_result = $subordinates_stmt->get_result();
                
                $subordinates = [];
                while ($subordinate = $subordinates_result->fetch_assoc()) {
                    $subordinate['id'] = intval($subordinate['id']);
                    $subordinate['ID_POSICION'] = intval($subordinate['ID_POSICION']);
                    $subordinates[] = $subordinate;
                }
                $subordinates_stmt->close();
                
                $relations['subordinates'] = $subordinates;
            }
        }
        
        $response_data['relations'] = $relations;
    }
    
    // === OBTENER ESTADÍSTICAS (SI SE SOLICITA) ===
    if ($include_stats) {
        $stats = getUserStats($conn, $user_data['id']);
        $response_data['stats'] = $stats;
    }
    
    // === INFORMACIÓN ADICIONAL ===
    $additional_info = [
        'can_be_deleted' => !$user_data['is_department_manager'],
        'requires_salary_review' => ($user_data['salary_in_range'] === false),
        'profile_incomplete' => ($user_data['profile_completion'] < 80),
        'is_new_employee' => ($user_data['months_employed'] < 6),
        'is_veteran' => ($user_data['years_employed'] >= 5),
        'last_updated_days_ago' => $user_data['updated_at'] ? 
            (new DateTime())->diff(new DateTime($user_data['updated_at']))->days : null
    ];
    
    $response_data['additional_info'] = $additional_info;
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Detalle de usuario obtenido exitosamente',
        'data' => $response_data
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