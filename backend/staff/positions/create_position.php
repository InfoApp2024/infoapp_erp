<?php
/**
 * POST /API_Infoapp/staff/positions/create_position.php
 * 
 * Endpoint para crear una nueva posición/cargo
 * Incluye validaciones completas y verificación de departamento
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
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

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método POST']);
}

try {
    // Incluir archivo de conexión
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }

    // ✅ VERIFICAR SI LAS TABLAS EXISTEN
    $tables_check = [
        'positions' => false,
        'departments' => false
    ];
    
    foreach ($tables_check as $table => $exists) {
        $check_result = $conn->query("SHOW TABLES LIKE '{$table}'");
        $tables_check[$table] = ($check_result && $check_result->num_rows > 0);
    }

    if (!$tables_check['positions']) {
        sendErrorResponse(500, 'La tabla positions no existe. Ejecute primero get_positions.php para crearla.');
    }

    // === OBTENER Y DECODIFICAR JSON ===
    $input = file_get_contents('php://input');
    if (empty($input)) {
        sendErrorResponse(400, 'No se recibieron datos en el request');
    }

    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        sendErrorResponse(400, 'JSON inválido: ' . json_last_error_msg());
    }

    // === VALIDACIONES DE CAMPOS REQUERIDOS ===
    $required_fields = ['title', 'department_id'];
    $missing_fields = [];

    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || trim($data[$field]) === '') {
            $missing_fields[] = $field;
        }
    }

    if (!empty($missing_fields)) {
        sendErrorResponse(400, 'Campos requeridos faltantes', [
            'missing_fields' => $missing_fields,
            'required_fields' => $required_fields
        ]);
    }

    // === EXTRAER Y LIMPIAR DATOS ===
    $title = trim($data['title']);
    $description = isset($data['description']) ? trim($data['description']) : null;
    $department_id = intval($data['department_id']);
    $min_salary = isset($data['min_salary']) && is_numeric($data['min_salary']) ? floatval($data['min_salary']) : null;
    $max_salary = isset($data['max_salary']) && is_numeric($data['max_salary']) ? floatval($data['max_salary']) : null;
    $is_active = isset($data['is_active']) ? boolval($data['is_active']) : true;
    $created_by = isset($data['created_by']) && is_numeric($data['created_by']) ? intval($data['created_by']) : null;

    // === VALIDACIONES DE FORMATO ===
    $validation_errors = [];

    // Validar título
    if (strlen($title) < 2) {
        $validation_errors['title'] = 'El título debe tener al menos 2 caracteres';
    } elseif (strlen($title) > 100) {
        $validation_errors['title'] = 'El título no puede exceder 100 caracteres';
    } elseif (!preg_match('/^[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s\-_\/\.]+$/u', $title)) {
        $validation_errors['title'] = 'El título contiene caracteres no válidos';
    }

    // Validar descripción si se proporciona
    if ($description !== null && strlen($description) > 500) {
        $validation_errors['description'] = 'La descripción no puede exceder 500 caracteres';
    }

    // Validar department_id
    if ($department_id <= 0) {
        $validation_errors['department_id'] = 'El ID del departamento debe ser un número positivo';
    }

    // Validar rangos salariales
    if ($min_salary !== null && $min_salary < 0) {
        $validation_errors['min_salary'] = 'El salario mínimo no puede ser negativo';
    }

    if ($max_salary !== null && $max_salary < 0) {
        $validation_errors['max_salary'] = 'El salario máximo no puede ser negativo';
    }

    if ($min_salary !== null && $max_salary !== null && $min_salary > $max_salary) {
        $validation_errors['salary_range'] = 'El salario mínimo no puede ser mayor al salario máximo';
    }

    if (!empty($validation_errors)) {
        sendErrorResponse(422, 'Datos de entrada inválidos', $validation_errors);
    }

    // === VERIFICAR QUE EL DEPARTAMENTO EXISTE ===
    if ($tables_check['departments']) {
        $check_department_sql = "SELECT id, name, is_active FROM departments WHERE id = ? AND deleted_at IS NULL";
        $dept_stmt = $conn->prepare($check_department_sql);
        
        if (!$dept_stmt) {
            sendErrorResponse(500, 'Error preparando consulta de departamento: ' . $conn->error);
        }

        $dept_stmt->bind_param('i', $department_id);
        
        if (!$dept_stmt->execute()) {
            sendErrorResponse(500, 'Error verificando departamento: ' . $dept_stmt->error);
        }

        $dept_result = $dept_stmt->get_result();
        if ($dept_result->num_rows === 0) {
            $dept_stmt->close();
            sendErrorResponse(404, 'El departamento especificado no existe', [
                'field' => 'department_id',
                'message' => 'Departamento no encontrado'
            ]);
        }

        $department_data = $dept_result->fetch_assoc();
        if (!$department_data['is_active']) {
            $dept_stmt->close();
            sendErrorResponse(422, 'El departamento especificado no está activo', [
                'field' => 'department_id',
                'message' => 'No se pueden crear cargos en departamentos inactivos'
            ]);
        }
        $dept_stmt->close();
    } else {
        // Si no existe tabla departments, crear referencia básica
        $department_data = [
            'id' => $department_id,
            'name' => "Departamento {$department_id}",
            'is_active' => true
        ];
    }

    // === VERIFICAR DUPLICADOS (título + departamento) ===
    $check_duplicate_sql = "SELECT id FROM positions WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND department_id = ? AND deleted_at IS NULL";
    $check_stmt = $conn->prepare($check_duplicate_sql);
    
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de duplicados: ' . $conn->error);
    }

    $check_stmt->bind_param('si', $title, $department_id);
    
    if (!$check_stmt->execute()) {
        sendErrorResponse(500, 'Error verificando duplicados: ' . $check_stmt->error);
    }

    $duplicate_result = $check_stmt->get_result();
    if ($duplicate_result->num_rows > 0) {
        $check_stmt->close();
        sendErrorResponse(409, 'Ya existe un cargo con ese título en el departamento', [
            'field' => 'title',
            'message' => 'El título del cargo debe ser único dentro del departamento'
        ]);
    }
    $check_stmt->close();

    // === INSERTAR POSICIÓN ===
    $conn->autocommit(false);

    try {
        // Insertar posición
        $insert_sql = "INSERT INTO positions (title, description, department_id, min_salary, max_salary, is_active, created_at, updated_at) 
                       VALUES (?, ?, ?, ?, ?, ?, NOW(), NOW())";
        
        $insert_stmt = $conn->prepare($insert_sql);
        if (!$insert_stmt) {
            throw new Exception('Error preparando inserción: ' . $conn->error);
        }

        $insert_stmt->bind_param('ssiddi', $title, $description, $department_id, $min_salary, $max_salary, $is_active);
        
        if (!$insert_stmt->execute()) {
            throw new Exception('Error ejecutando inserción: ' . $insert_stmt->error);
        }

        if ($insert_stmt->affected_rows === 0) {
            throw new Exception('No se pudo crear la posición');
        }

        $position_id = $conn->insert_id;
        $insert_stmt->close();

        // === OBTENER POSICIÓN CREADA CON INFORMACIÓN COMPLETA ===
        if ($tables_check['departments']) {
            $select_sql = "SELECT 
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
            INNER JOIN departments d ON p.department_id = d.id
            WHERE p.id = ?";
        } else {
            $select_sql = "SELECT 
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
            FROM positions p
            WHERE p.id = ?";
        }

        $select_stmt = $conn->prepare($select_sql);
        if (!$select_stmt) {
            throw new Exception('Error preparando consulta de posición: ' . $conn->error);
        }

        $select_stmt->bind_param('i', $position_id);
        
        if (!$select_stmt->execute()) {
            throw new Exception('Error obteniendo posición creada: ' . $select_stmt->error);
        }

        $position_result = $select_stmt->get_result();
        $position_data = $position_result->fetch_assoc();
        $select_stmt->close();

        // Formatear datos
        $position_data['id'] = intval($position_data['id']);
        $position_data['department_id'] = intval($position_data['department_id']);
        $position_data['min_salary'] = $position_data['min_salary'] ? floatval($position_data['min_salary']) : null;
        $position_data['max_salary'] = $position_data['max_salary'] ? floatval($position_data['max_salary']) : null;
        $position_data['is_active'] = boolval($position_data['is_active']);
        $position_data['department_is_active'] = boolval($position_data['department_is_active']);
        $position_data['has_salary_range'] = !empty($position_data['min_salary']) && !empty($position_data['max_salary']);
        
        if ($position_data['has_salary_range']) {
            $position_data['salary_range_text'] = '$' . number_format($position_data['min_salary'], 2) . ' - $' . number_format($position_data['max_salary'], 2);
        } else {
            $position_data['salary_range_text'] = null;
        }

        // === REGISTRAR EN AUDITORÍA (si tienes tabla de auditoría) ===
        if ($created_by !== null) {
            $audit_table_check = $conn->query("SHOW TABLES LIKE 'positions_audit_log'");
            
            if ($audit_table_check && $audit_table_check->num_rows > 0) {
                $audit_sql = "INSERT INTO positions_audit_log (position_id, action, new_values, changed_by, ip_address, created_at) 
                              VALUES (?, 'created', ?, ?, ?, NOW())";
                
                $audit_stmt = $conn->prepare($audit_sql);
                if ($audit_stmt) {
                    $new_values_json = json_encode($position_data);
                    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    
                    $audit_stmt->bind_param('isis', $position_id, $new_values_json, $created_by, $ip_address);
                    $audit_stmt->execute();
                    $audit_stmt->close();
                }
            }
        }

        // Confirmar transacción
        $conn->commit();

        // === INFORMACIÓN ADICIONAL ===
        $position_info = [
            'total_employees' => 0,
            'can_assign_employees' => true,
            'created_successfully' => true,
            'can_be_edited' => true,
            'can_be_deleted' => true,
            'department_info' => [
                'id' => intval($department_data['id']),
                'name' => $department_data['name'],
                'is_active' => boolval($department_data['is_active'])
            ]
        ];

        // === RESPUESTA EXITOSA ===
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => "Cargo '{$title}' creado exitosamente en {$department_data['name']}",
            'data' => $position_data,
            'position_info' => $position_info
        ], JSON_UNESCAPED_UNICODE);

    } catch (Exception $e) {
        // Rollback en caso de error
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
} finally {
    // Restaurar autocommit y cerrar conexión
    if (isset($conn)) {
        $conn->autocommit(true);
        $conn->close();
    }
}
?>