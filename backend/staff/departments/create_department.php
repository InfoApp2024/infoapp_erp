<?php
/**
 * POST /API_Infoapp/staff/departments/create_department.php
 * 
 * Endpoint para crear un nuevo departamento
 * Incluye validaciones completas y creación automática de registro de auditoría
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
    // ✅ CORREGIDO: Incluir archivo de conexión con ruta correcta
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }

    // ✅ VERIFICAR SI LA TABLA DEPARTMENTS EXISTE
    $table_check = $conn->query("SHOW TABLES LIKE 'departments'");
    if (!$table_check || $table_check->num_rows === 0) {
        // Crear tabla si no existe
        $create_table_sql = "CREATE TABLE IF NOT EXISTS departments (
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
        
        if (!$conn->query($create_table_sql)) {
            sendErrorResponse(500, 'Error creando tabla departments: ' . $conn->error);
        }
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
    $required_fields = ['name'];
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
    $name = trim($data['name']);
    $description = isset($data['description']) ? trim($data['description']) : null;
    $manager_id = isset($data['manager_id']) && is_numeric($data['manager_id']) ? intval($data['manager_id']) : null;
    $is_active = isset($data['is_active']) ? boolval($data['is_active']) : true;
    $created_by = isset($data['created_by']) && is_numeric($data['created_by']) ? intval($data['created_by']) : null;

    // === VALIDACIONES DE FORMATO ===
    $validation_errors = [];

    // Validar nombre
    if (strlen($name) < 2) {
        $validation_errors['name'] = 'El nombre debe tener al menos 2 caracteres';
    } elseif (strlen($name) > 100) {
        $validation_errors['name'] = 'El nombre no puede exceder 100 caracteres';
    } elseif (!preg_match('/^[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s\-_]+$/u', $name)) {
        $validation_errors['name'] = 'El nombre contiene caracteres no válidos';
    }

    // Validar descripción si se proporciona
    if ($description !== null && strlen($description) > 500) {
        $validation_errors['description'] = 'La descripción no puede exceder 500 caracteres';
    }

    if (!empty($validation_errors)) {
        sendErrorResponse(422, 'Datos de entrada inválidos', $validation_errors);
    }

    // === VERIFICAR DUPLICADOS ===
    $check_duplicate_sql = "SELECT id FROM departments WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) AND deleted_at IS NULL";
    $check_stmt = $conn->prepare($check_duplicate_sql);
    
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de duplicados: ' . $conn->error);
    }

    $check_stmt->bind_param('s', $name);
    
    if (!$check_stmt->execute()) {
        sendErrorResponse(500, 'Error verificando duplicados: ' . $check_stmt->error);
    }

    $duplicate_result = $check_stmt->get_result();
    if ($duplicate_result->num_rows > 0) {
        $check_stmt->close();
        sendErrorResponse(409, 'Ya existe un departamento con ese nombre', [
            'field' => 'name',
            'message' => 'El nombre del departamento debe ser único'
        ]);
    }
    $check_stmt->close();

    // === VERIFICAR MANAGER SI SE PROPORCIONA (SOLO SI TABLA STAFF EXISTE) ===
    if ($manager_id !== null) {
        $staff_table_check = $conn->query("SHOW TABLES LIKE 'staff'");
        
        if ($staff_table_check && $staff_table_check->num_rows > 0) {
            $check_manager_sql = "SELECT id, first_name, last_name, is_active FROM staff WHERE id = ? AND deleted_at IS NULL";
            $manager_stmt = $conn->prepare($check_manager_sql);
            
            if (!$manager_stmt) {
                sendErrorResponse(500, 'Error preparando consulta de manager: ' . $conn->error);
            }

            $manager_stmt->bind_param('i', $manager_id);
            
            if (!$manager_stmt->execute()) {
                sendErrorResponse(500, 'Error verificando manager: ' . $manager_stmt->error);
            }

            $manager_result = $manager_stmt->get_result();
            if ($manager_result->num_rows === 0) {
                $manager_stmt->close();
                sendErrorResponse(404, 'El empleado seleccionado como manager no existe', [
                    'field' => 'manager_id',
                    'message' => 'Manager no encontrado'
                ]);
            }

            $manager_data = $manager_result->fetch_assoc();
            if (!$manager_data['is_active']) {
                $manager_stmt->close();
                sendErrorResponse(422, 'El empleado seleccionado como manager no está activo', [
                    'field' => 'manager_id',
                    'message' => 'El manager debe estar activo'
                ]);
            }
            $manager_stmt->close();
        } else {
            // Si no existe tabla staff, ignorar manager_id por ahora
            $manager_id = null;
        }
    }

    // === INSERTAR DEPARTAMENTO ===
    $conn->autocommit(false);

    try {
        // Insertar departamento
        $insert_sql = "INSERT INTO departments (name, description, manager_id, is_active, created_at, updated_at) 
                       VALUES (?, ?, ?, ?, NOW(), NOW())";
        
        $insert_stmt = $conn->prepare($insert_sql);
        if (!$insert_stmt) {
            throw new Exception('Error preparando inserción: ' . $conn->error);
        }

        $insert_stmt->bind_param('ssii', $name, $description, $manager_id, $is_active);
        
        if (!$insert_stmt->execute()) {
            throw new Exception('Error ejecutando inserción: ' . $insert_stmt->error);
        }

        if ($insert_stmt->affected_rows === 0) {
            throw new Exception('No se pudo crear el departamento');
        }

        $department_id = $conn->insert_id;
        $insert_stmt->close();

        // === OBTENER DEPARTAMENTO CREADO CON INFORMACIÓN COMPLETA ===
        // Verificar si tabla staff existe para incluir información de manager
        $staff_exists = $conn->query("SHOW TABLES LIKE 'staff'");
        
        if ($staff_exists && $staff_exists->num_rows > 0) {
            $select_sql = "SELECT 
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
                END as manager_email
            FROM departments d
            LEFT JOIN staff m ON d.manager_id = m.id AND m.deleted_at IS NULL
            WHERE d.id = ?";
        } else {
            $select_sql = "SELECT 
                d.id,
                d.name,
                d.description,
                d.manager_id,
                d.is_active,
                d.created_at,
                d.updated_at,
                NULL as manager_name,
                NULL as manager_email
            FROM departments d
            WHERE d.id = ?";
        }

        $select_stmt = $conn->prepare($select_sql);
        if (!$select_stmt) {
            throw new Exception('Error preparando consulta de departamento: ' . $conn->error);
        }

        $select_stmt->bind_param('i', $department_id);
        
        if (!$select_stmt->execute()) {
            throw new Exception('Error obteniendo departamento creado: ' . $select_stmt->error);
        }

        $department_result = $select_stmt->get_result();
        $department_data = $department_result->fetch_assoc();
        $select_stmt->close();

        // Formatear datos
        $department_data['id'] = intval($department_data['id']);
        $department_data['manager_id'] = $department_data['manager_id'] ? intval($department_data['manager_id']) : null;
        $department_data['is_active'] = boolval($department_data['is_active']);
        $department_data['has_manager'] = !empty($department_data['manager_id']);

        // === REGISTRAR EN AUDITORÍA (si tienes tabla de auditoría) ===
        if ($created_by !== null) {
            $audit_table_check = $conn->query("SHOW TABLES LIKE 'departments_audit_log'");
            
            if ($audit_table_check && $audit_table_check->num_rows > 0) {
                $audit_sql = "INSERT INTO departments_audit_log (department_id, action, new_values, changed_by, ip_address, created_at) 
                              VALUES (?, 'created', ?, ?, ?, NOW())";
                
                $audit_stmt = $conn->prepare($audit_sql);
                if ($audit_stmt) {
                    $new_values_json = json_encode($department_data);
                    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    
                    $audit_stmt->bind_param('issi', $department_id, $new_values_json, $created_by, $ip_address);
                    $audit_stmt->execute();
                    $audit_stmt->close();
                }
            }
        }

        // Confirmar transacción
        $conn->commit();

        // === INFORMACIÓN ADICIONAL ===
        $department_info = [
            'total_positions' => 0,
            'total_employees' => 0,
            'created_successfully' => true,
            'can_be_edited' => true,
            'can_be_deleted' => true // Se puede eliminar si no tiene empleados
        ];

        // === RESPUESTA EXITOSA ===
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => "Departamento '{$name}' creado exitosamente",
            'data' => $department_data,
            'department_info' => $department_info
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