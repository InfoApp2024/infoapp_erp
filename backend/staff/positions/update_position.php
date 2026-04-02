<?php
/**
 * PUT /API_Infoapp/staff/positions/update_position.php
 * 
 * Endpoint para actualizar una posición/cargo existente
 * Incluye validaciones completas y registro de auditoría de cambios
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: PUT, OPTIONS');
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

// Solo permitir método PUT
if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método PUT']);
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
        'departments' => false,
        'staff' => false
    ];
    
    foreach ($tables_check as $table => $exists) {
        $check_result = $conn->query("SHOW TABLES LIKE '{$table}'");
        $tables_check[$table] = ($check_result && $check_result->num_rows > 0);
    }

    if (!$tables_check['positions']) {
        sendErrorResponse(500, 'La tabla positions no existe');
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
    if (!isset($data['id']) || !is_numeric($data['id'])) {
        sendErrorResponse(400, 'ID de posición requerido y debe ser numérico');
    }

    $position_id = intval($data['id']);

    // === VERIFICAR QUE LA POSICIÓN EXISTE ===
    if ($tables_check['staff']) {
        // Con tabla staff disponible
        $check_sql = "SELECT 
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
            COUNT(DISTINCT s.id) as employee_count,
            COUNT(DISTINCT sa.id) as active_employee_count
        FROM positions p
        LEFT JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL
        LEFT JOIN staff s ON p.id = s.position_id AND s.deleted_at IS NULL
        LEFT JOIN staff sa ON p.id = sa.position_id AND sa.deleted_at IS NULL AND sa.is_active = 1
        WHERE p.id = ? AND p.deleted_at IS NULL
        GROUP BY p.id";
    } else {
        // Sin tabla staff
        $check_sql = "SELECT 
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
            0 as employee_count,
            0 as active_employee_count
        FROM positions p
        LEFT JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL
        WHERE p.id = ? AND p.deleted_at IS NULL";
    }

    $check_stmt = $conn->prepare($check_sql);
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de verificación: ' . $conn->error);
    }

    $check_stmt->bind_param('i', $position_id);
    
    if (!$check_stmt->execute()) {
        sendErrorResponse(500, 'Error verificando posición: ' . $check_stmt->error);
    }

    $check_result = $check_stmt->get_result();
    if ($check_result->num_rows === 0) {
        $check_stmt->close();
        sendErrorResponse(404, 'Posición no encontrada', [
            'position_id' => $position_id,
            'message' => 'La posición no existe o fue eliminada'
        ]);
    }

    $current_data = $check_result->fetch_assoc();
    $check_stmt->close();

    // === EXTRAER Y LIMPIAR DATOS DE ACTUALIZACIÓN ===
    $fields_to_update = [];
    $validation_errors = [];
    $old_values = [];
    $new_values = [];

    // Procesar campo title
    if (isset($data['title'])) {
        $title = trim($data['title']);
        
        if (strlen($title) < 2) {
            $validation_errors['title'] = 'El título debe tener al menos 2 caracteres';
        } elseif (strlen($title) > 100) {
            $validation_errors['title'] = 'El título no puede exceder 100 caracteres';
        } elseif (!preg_match('/^[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s\-_\/\.]+$/u', $title)) {
            $validation_errors['title'] = 'El título contiene caracteres no válidos';
        } else {
            // Verificar duplicados (excluyendo la posición actual)
            $check_duplicate_sql = "SELECT id FROM positions WHERE LOWER(TRIM(title)) = LOWER(TRIM(?)) AND department_id = ? AND id != ? AND deleted_at IS NULL";
            $duplicate_stmt = $conn->prepare($check_duplicate_sql);
            
            if ($duplicate_stmt) {
                $duplicate_stmt->bind_param('sii', $title, $current_data['department_id'], $position_id);
                $duplicate_stmt->execute();
                $duplicate_result = $duplicate_stmt->get_result();
                
                if ($duplicate_result->num_rows > 0) {
                    $validation_errors['title'] = 'Ya existe otra posición con ese título en el departamento';
                } else {
                    $fields_to_update['title'] = $title;
                    $old_values['title'] = $current_data['title'];
                    $new_values['title'] = $title;
                }
                $duplicate_stmt->close();
            }
        }
    }

    // Procesar campo description
    if (isset($data['description'])) {
        $description = $data['description'] === null ? null : trim($data['description']);
        
        if ($description !== null && strlen($description) > 500) {
            $validation_errors['description'] = 'La descripción no puede exceder 500 caracteres';
        } else {
            $fields_to_update['description'] = $description;
            $old_values['description'] = $current_data['description'];
            $new_values['description'] = $description;
        }
    }

    // Procesar campo department_id
    if (isset($data['department_id'])) {
        $department_id = intval($data['department_id']);
        
        if ($department_id <= 0) {
            $validation_errors['department_id'] = 'El ID del departamento debe ser un número positivo';
        } else {
            // Verificar que el departamento existe y está activo (solo si tabla departments existe)
            if ($tables_check['departments']) {
                $check_dept_sql = "SELECT id, name, is_active FROM departments WHERE id = ? AND deleted_at IS NULL";
                $dept_stmt = $conn->prepare($check_dept_sql);
                
                if ($dept_stmt) {
                    $dept_stmt->bind_param('i', $department_id);
                    $dept_stmt->execute();
                    $dept_result = $dept_stmt->get_result();
                    
                    if ($dept_result->num_rows === 0) {
                        $validation_errors['department_id'] = 'El departamento especificado no existe';
                    } else {
                        $dept_data = $dept_result->fetch_assoc();
                        if (!$dept_data['is_active']) {
                            $validation_errors['department_id'] = 'El departamento especificado no está activo';
                        } else {
                            $fields_to_update['department_id'] = $department_id;
                            $old_values['department_id'] = $current_data['department_id'];
                            $new_values['department_id'] = $department_id;
                        }
                    }
                    $dept_stmt->close();
                }
            } else {
                // Si no existe tabla departments, permitir cambio
                $fields_to_update['department_id'] = $department_id;
                $old_values['department_id'] = $current_data['department_id'];
                $new_values['department_id'] = $department_id;
            }
        }
    }

    // Procesar campo min_salary
    if (isset($data['min_salary'])) {
        $min_salary = $data['min_salary'] === null ? null : floatval($data['min_salary']);
        
        if ($min_salary !== null && $min_salary < 0) {
            $validation_errors['min_salary'] = 'El salario mínimo no puede ser negativo';
        } else {
            $fields_to_update['min_salary'] = $min_salary;
            $old_values['min_salary'] = $current_data['min_salary'];
            $new_values['min_salary'] = $min_salary;
        }
    }

    // Procesar campo max_salary
    if (isset($data['max_salary'])) {
        $max_salary = $data['max_salary'] === null ? null : floatval($data['max_salary']);
        
        if ($max_salary !== null && $max_salary < 0) {
            $validation_errors['max_salary'] = 'El salario máximo no puede ser negativo';
        } else {
            $fields_to_update['max_salary'] = $max_salary;
            $old_values['max_salary'] = $current_data['max_salary'];
            $new_values['max_salary'] = $max_salary;
        }
    }

    // Validar rango salarial después de procesar ambos campos
    $final_min = isset($fields_to_update['min_salary']) ? $fields_to_update['min_salary'] : $current_data['min_salary'];
    $final_max = isset($fields_to_update['max_salary']) ? $fields_to_update['max_salary'] : $current_data['max_salary'];
    
    if ($final_min !== null && $final_max !== null && $final_min > $final_max) {
        $validation_errors['salary_range'] = 'El salario mínimo no puede ser mayor al salario máximo';
    }

    // Procesar campo is_active
    if (isset($data['is_active'])) {
        $is_active = boolval($data['is_active']);
        
        // Si se está desactivando, verificar que no tenga empleados activos
        if (!$is_active && intval($current_data['active_employee_count']) > 0) {
            $validation_errors['is_active'] = 'No se puede desactivar una posición que tiene empleados activos asignados';
        } else {
            $fields_to_update['is_active'] = $is_active ? 1 : 0;
            $old_values['is_active'] = boolval($current_data['is_active']);
            $new_values['is_active'] = $is_active;
        }
    }

    // === VERIFICAR ERRORES DE VALIDACIÓN ===
    if (!empty($validation_errors)) {
        sendErrorResponse(422, 'Datos de entrada inválidos', $validation_errors);
    }

    // === VERIFICAR SI HAY CAMBIOS ===
    if (empty($fields_to_update)) {
        sendErrorResponse(400, 'No se detectaron cambios para actualizar', [
            'message' => 'Debe proporcionar al menos un campo para actualizar',
            'current_data' => $current_data
        ]);
    }

    // === OBTENER INFORMACIÓN DEL USUARIO QUE ACTUALIZA ===
    $updated_by = isset($data['updated_by']) && is_numeric($data['updated_by']) ? intval($data['updated_by']) : null;

    // === ACTUALIZAR POSICIÓN ===
    $conn->autocommit(false);

    try {
        // Construir consulta de actualización dinámicamente
        $update_fields = [];
        $param_types = '';
        $param_values = [];

        foreach ($fields_to_update as $field => $value) {
            $update_fields[] = "$field = ?";
            if ($field === 'is_active' || $field === 'department_id') {
                $param_types .= 'i';
                $param_values[] = $value;
            } elseif ($field === 'min_salary' || $field === 'max_salary') {
                $param_types .= 'd';
                $param_values[] = $value;
            } else {
                $param_types .= 's';
                $param_values[] = $value;
            }
        }

        $update_sql = "UPDATE positions SET " . implode(', ', $update_fields) . ", updated_at = NOW() WHERE id = ?";
        $param_types .= 'i';
        $param_values[] = $position_id;

        $update_stmt = $conn->prepare($update_sql);
        if (!$update_stmt) {
            throw new Exception('Error preparando actualización: ' . $conn->error);
        }

        $update_stmt->bind_param($param_types, ...$param_values);
        
        if (!$update_stmt->execute()) {
            throw new Exception('Error ejecutando actualización: ' . $update_stmt->error);
        }

        if ($update_stmt->affected_rows === 0) {
            throw new Exception('No se realizaron cambios en la posición');
        }

        $update_stmt->close();

        // === OBTENER POSICIÓN ACTUALIZADA ===
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
            LEFT JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL
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
            throw new Exception('Error obteniendo posición actualizada: ' . $select_stmt->error);
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

        // === REGISTRAR AUDITORÍA (solo si tabla existe) ===
        if ($updated_by !== null) {
            $audit_table_check = $conn->query("SHOW TABLES LIKE 'positions_audit_log'");
            
            if ($audit_table_check && $audit_table_check->num_rows > 0) {
                $audit_sql = "INSERT INTO positions_audit_log (position_id, action, old_values, new_values, changed_by, ip_address, created_at) 
                              VALUES (?, 'updated', ?, ?, ?, ?, NOW())";
                
                $audit_stmt = $conn->prepare($audit_sql);
                if ($audit_stmt) {
                    $old_values_json = json_encode($old_values);
                    $new_values_json = json_encode($new_values);
                    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    
                    $audit_stmt->bind_param('issis', $position_id, $old_values_json, $new_values_json, $updated_by, $ip_address);
                    $audit_stmt->execute();
                    $audit_stmt->close();
                }
            }
        }

        // Confirmar transacción
        $conn->commit();

        // === INFORMACIÓN DE CAMBIOS ===
        $changes_info = [
            'fields_updated' => array_keys($fields_to_update),
            'total_changes' => count($fields_to_update),
            'updated_by' => $updated_by,
            'update_timestamp' => date('Y-m-d H:i:s'),
            'tables_available' => $tables_check
        ];

        // === RESPUESTA EXITOSA ===
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => "Posición actualizada exitosamente",
            'data' => $position_data,
            'changes' => $changes_info,
            'old_values' => $old_values,
            'new_values' => $new_values
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