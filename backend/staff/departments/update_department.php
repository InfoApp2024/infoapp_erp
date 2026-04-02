<?php
/**
 * PUT /API_Infoapp/staff/departments/update_department.php
 * 
 * Endpoint para actualizar un departamento existente
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
    // ✅ CORREGIDO: Incluir archivo de conexión con ruta correcta
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }

    // ✅ VERIFICAR SI LAS TABLAS EXISTEN
    $tables_check = [
        'departments' => false,
        'staff' => false,
        'positions' => false
    ];
    
    foreach ($tables_check as $table => $exists) {
        $check_result = $conn->query("SHOW TABLES LIKE '{$table}'");
        $tables_check[$table] = ($check_result && $check_result->num_rows > 0);
    }

    if (!$tables_check['departments']) {
        sendErrorResponse(500, 'La tabla departments no existe');
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
        sendErrorResponse(400, 'ID de departamento requerido y debe ser numérico');
    }

    $department_id = intval($data['id']);

    // === VERIFICAR QUE EL DEPARTAMENTO EXISTE ===
    if ($tables_check['staff'] && $tables_check['positions']) {
        // Consulta completa con staff y positions
        $check_sql = "SELECT 
            d.id,
            d.name,
            d.description,
            d.manager_id,
            d.is_active,
            d.created_at,
            d.updated_at,
            COUNT(DISTINCT s.id) as employee_count,
            COUNT(DISTINCT p.id) as position_count
        FROM departments d
        LEFT JOIN staff s ON d.id = s.department_id AND s.deleted_at IS NULL
        LEFT JOIN positions p ON d.id = p.department_id
        WHERE d.id = ? AND d.deleted_at IS NULL
        GROUP BY d.id";
    } elseif ($tables_check['staff']) {
        // Solo con staff
        $check_sql = "SELECT 
            d.id,
            d.name,
            d.description,
            d.manager_id,
            d.is_active,
            d.created_at,
            d.updated_at,
            COUNT(DISTINCT s.id) as employee_count,
            0 as position_count
        FROM departments d
        LEFT JOIN staff s ON d.id = s.department_id AND s.deleted_at IS NULL
        WHERE d.id = ? AND d.deleted_at IS NULL
        GROUP BY d.id";
    } else {
        // Solo departments
        $check_sql = "SELECT 
            d.id,
            d.name,
            d.description,
            d.manager_id,
            d.is_active,
            d.created_at,
            d.updated_at,
            0 as employee_count,
            0 as position_count
        FROM departments d
        WHERE d.id = ? AND d.deleted_at IS NULL";
    }

    $check_stmt = $conn->prepare($check_sql);
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de verificación: ' . $conn->error);
    }

    $check_stmt->bind_param('i', $department_id);
    
    if (!$check_stmt->execute()) {
        sendErrorResponse(500, 'Error verificando departamento: ' . $check_stmt->error);
    }

    $check_result = $check_stmt->get_result();
    if ($check_result->num_rows === 0) {
        $check_stmt->close();
        sendErrorResponse(404, 'Departamento no encontrado', [
            'department_id' => $department_id,
            'message' => 'El departamento no existe o fue eliminado'
        ]);
    }

    $current_data = $check_result->fetch_assoc();
    $check_stmt->close();

    // === EXTRAER Y LIMPIAR DATOS DE ACTUALIZACIÓN ===
    $fields_to_update = [];
    $validation_errors = [];
    $old_values = [];
    $new_values = [];

    // Procesar campo name
    if (isset($data['name'])) {
        $name = trim($data['name']);
        
        if (strlen($name) < 2) {
            $validation_errors['name'] = 'El nombre debe tener al menos 2 caracteres';
        } elseif (strlen($name) > 100) {
            $validation_errors['name'] = 'El nombre no puede exceder 100 caracteres';
        } elseif (!preg_match('/^[a-zA-ZáéíóúÁÉÍÓÚñÑ0-9\s\-_]+$/u', $name)) {
            $validation_errors['name'] = 'El nombre contiene caracteres no válidos';
        } else {
            // Verificar duplicados (excluyendo el departamento actual)
            $check_duplicate_sql = "SELECT id FROM departments WHERE LOWER(TRIM(name)) = LOWER(TRIM(?)) AND id != ? AND deleted_at IS NULL";
            $duplicate_stmt = $conn->prepare($check_duplicate_sql);
            
            if ($duplicate_stmt) {
                $duplicate_stmt->bind_param('si', $name, $department_id);
                $duplicate_stmt->execute();
                $duplicate_result = $duplicate_stmt->get_result();
                
                if ($duplicate_result->num_rows > 0) {
                    $validation_errors['name'] = 'Ya existe otro departamento con ese nombre';
                } else {
                    $fields_to_update['name'] = $name;
                    $old_values['name'] = $current_data['name'];
                    $new_values['name'] = $name;
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

    // Procesar campo manager_id (solo si tabla staff existe)
    if (isset($data['manager_id'])) {
        $manager_id = $data['manager_id'] === null ? null : intval($data['manager_id']);
        
        if ($manager_id !== null && $tables_check['staff']) {
            // Verificar que el manager existe y está activo
            $check_manager_sql = "SELECT id, first_name, last_name, is_active, department_id FROM staff WHERE id = ? AND deleted_at IS NULL";
            $manager_stmt = $conn->prepare($check_manager_sql);
            
            if ($manager_stmt) {
                $manager_stmt->bind_param('i', $manager_id);
                $manager_stmt->execute();
                $manager_result = $manager_stmt->get_result();
                
                if ($manager_result->num_rows === 0) {
                    $validation_errors['manager_id'] = 'El empleado seleccionado como manager no existe';
                } else {
                    $manager_data = $manager_result->fetch_assoc();
                    if (!$manager_data['is_active']) {
                        $validation_errors['manager_id'] = 'El empleado seleccionado como manager no está activo';
                    } else {
                        $fields_to_update['manager_id'] = $manager_id;
                        $old_values['manager_id'] = $current_data['manager_id'];
                        $new_values['manager_id'] = $manager_id;
                    }
                }
                $manager_stmt->close();
            }
        } elseif ($manager_id === null) {
            // Permitir limpiar manager
            $fields_to_update['manager_id'] = null;
            $old_values['manager_id'] = $current_data['manager_id'];
            $new_values['manager_id'] = null;
        } elseif (!$tables_check['staff']) {
            // Si no existe tabla staff, ignorar manager_id
            $validation_errors['manager_id'] = 'No se puede asignar manager: tabla staff no disponible';
        }
    }

    // Procesar campo is_active
    if (isset($data['is_active'])) {
        $is_active = boolval($data['is_active']);
        
        // Si se está desactivando, verificar que no tenga empleados activos
        if (!$is_active && intval($current_data['employee_count']) > 0) {
            $validation_errors['is_active'] = 'No se puede desactivar un departamento que tiene empleados asignados';
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

    // === ACTUALIZAR DEPARTAMENTO ===
    $conn->autocommit(false);

    try {
        // Construir consulta de actualización dinámicamente
        $update_fields = [];
        $param_types = '';
        $param_values = [];

        foreach ($fields_to_update as $field => $value) {
            $update_fields[] = "$field = ?";
            if ($field === 'is_active') {
                $param_types .= 'i';
                $param_values[] = $value;
            } elseif ($field === 'manager_id') {
                $param_types .= 'i';
                $param_values[] = $value;
            } else {
                $param_types .= 's';
                $param_values[] = $value;
            }
        }

        $update_sql = "UPDATE departments SET " . implode(', ', $update_fields) . ", updated_at = NOW() WHERE id = ?";
        $param_types .= 'i';
        $param_values[] = $department_id;

        $update_stmt = $conn->prepare($update_sql);
        if (!$update_stmt) {
            throw new Exception('Error preparando actualización: ' . $conn->error);
        }

        $update_stmt->bind_param($param_types, ...$param_values);
        
        if (!$update_stmt->execute()) {
            throw new Exception('Error ejecutando actualización: ' . $update_stmt->error);
        }

        if ($update_stmt->affected_rows === 0) {
            throw new Exception('No se realizaron cambios en el departamento');
        }

        $update_stmt->close();

        // === OBTENER DEPARTAMENTO ACTUALIZADO ===
        if ($tables_check['staff']) {
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
            throw new Exception('Error obteniendo departamento actualizado: ' . $select_stmt->error);
        }

        $department_result = $select_stmt->get_result();
        $department_data = $department_result->fetch_assoc();
        $select_stmt->close();

        // Formatear datos
        $department_data['id'] = intval($department_data['id']);
        $department_data['manager_id'] = $department_data['manager_id'] ? intval($department_data['manager_id']) : null;
        $department_data['is_active'] = boolval($department_data['is_active']);
        $department_data['has_manager'] = !empty($department_data['manager_id']);

        // === REGISTRAR AUDITORÍA (solo si tabla existe) ===
        if ($updated_by !== null) {
            $audit_table_check = $conn->query("SHOW TABLES LIKE 'departments_audit_log'");
            
            if ($audit_table_check && $audit_table_check->num_rows > 0) {
                $audit_sql = "INSERT INTO departments_audit_log (department_id, action, old_values, new_values, changed_by, ip_address, created_at) 
                              VALUES (?, 'updated', ?, ?, ?, ?, NOW())";
                
                $audit_stmt = $conn->prepare($audit_sql);
                if ($audit_stmt) {
                    $old_values_json = json_encode($old_values);
                    $new_values_json = json_encode($new_values);
                    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    
                    $audit_stmt->bind_param('issis', $department_id, $old_values_json, $new_values_json, $updated_by, $ip_address);
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
            'message' => "Departamento actualizado exitosamente",
            'data' => $department_data,
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