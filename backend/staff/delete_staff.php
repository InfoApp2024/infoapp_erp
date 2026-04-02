<?php
/**
 * DELETE /API_Infoapp/staff/delete_staff.php
 * 
 * Endpoint para eliminar/desactivar un empleado
 * Soporta eliminación suave (soft delete) y eliminación permanente
 * Incluye verificación de dependencias
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: DELETE, OPTIONS');
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

// Función para verificar dependencias del empleado
function checkStaffDependencies($conn, $staff_id) {
    $dependencies = [];
    
    // Verificar si es manager de algún departamento
    $dept_sql = "SELECT COUNT(*) as count, GROUP_CONCAT(name SEPARATOR ', ') as departments 
                 FROM departments WHERE manager_id = ? AND is_active = 1";
    $dept_stmt = $conn->prepare($dept_sql);
    if ($dept_stmt) {
        $dept_stmt->bind_param("i", $staff_id);
        $dept_stmt->execute();
        $dept_result = $dept_stmt->get_result();
        $dept_data = $dept_result->fetch_assoc();
        $dept_stmt->close();
        
        if ($dept_data['count'] > 0) {
            $dependencies['departments'] = [
                'count' => $dept_data['count'],
                'message' => "Es manager de {$dept_data['count']} departamento(s): {$dept_data['departments']}",
                'blocking' => true
            ];
        }
    }
    
    // Verificar si tiene registros en otras tablas (ejemplos)
    $tables_to_check = [
        'staff_attendance' => 'registros de asistencia',
        'staff_evaluations' => 'evaluaciones de desempeño',
        'staff_documents' => 'documentos',
        'inventory_movements' => 'movimientos de inventario'
    ];
    
    foreach ($tables_to_check as $table => $description) {
        // Verificar si la tabla existe
        $table_exists_sql = "SHOW TABLES LIKE ?";
        $table_exists_stmt = $conn->prepare($table_exists_sql);
        if ($table_exists_stmt) {
            $table_exists_stmt->bind_param("s", $table);
            $table_exists_stmt->execute();
            $table_exists_result = $table_exists_stmt->get_result();
            $table_exists_stmt->close();
            
            if ($table_exists_result->num_rows > 0) {
                // La tabla existe, verificar registros
                $check_sql = "SELECT COUNT(*) as count FROM {$table} WHERE created_by = ? OR updated_by = ?";
                $check_stmt = $conn->prepare($check_sql);
                if ($check_stmt) {
                    $check_stmt->bind_param("ii", $staff_id, $staff_id);
                    $check_stmt->execute();
                    $check_result = $check_stmt->get_result();
                    $check_data = $check_result->fetch_assoc();
                    $check_stmt->close();
                    
                    if ($check_data['count'] > 0) {
                        $dependencies[$table] = [
                            'count' => $check_data['count'],
                            'message' => "Tiene {$check_data['count']} {$description}",
                            'blocking' => false // No bloquea eliminación, solo informa
                        ];
                    }
                }
            }
        }
    }
    
    return $dependencies;
}

// Manejar preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir método DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método DELETE']);
}

try {
    // Incluir archivo de conexión existente
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }
    
    // Obtener datos del cuerpo de la petición
    $inputRaw = file_get_contents('php://input');
    $input = json_decode($inputRaw, true);
    
    if (!$input) {
        sendErrorResponse(400, 'No se recibieron datos válidos en formato JSON');
    }
    
    // === VALIDAR ID REQUERIDO ===
    if (!isset($input['id']) || empty($input['id']) || !is_numeric($input['id'])) {
        sendErrorResponse(400, 'ID de empleado es requerido y debe ser numérico');
    }
    
    $staff_id = intval($input['id']);
    
    // === PARÁMETROS DE ELIMINACIÓN ===
    $soft_delete = isset($input['soft_delete']) ? boolval($input['soft_delete']) : true;
    $force = isset($input['force']) ? boolval($input['force']) : false;
    $reason = isset($input['reason']) ? trim($input['reason']) : 'Eliminación solicitada';
    $transfer_departments_to = isset($input['transfer_departments_to']) ? intval($input['transfer_departments_to']) : null;
    
    // === VERIFICAR QUE EL EMPLEADO EXISTE ===
    $check_staff_sql = "SELECT * FROM staff WHERE id = ?";
    $check_staff_stmt = $conn->prepare($check_staff_sql);
    if (!$check_staff_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de verificación');
    }
    
    $check_staff_stmt->bind_param("i", $staff_id);
    $check_staff_stmt->execute();
    $staff_result = $check_staff_stmt->get_result();
    $existing_staff = $staff_result->fetch_assoc();
    $check_staff_stmt->close();
    
    if (!$existing_staff) {
        sendErrorResponse(404, 'Empleado no encontrado', ['id' => 'El empleado especificado no existe']);
    }
    
    // === VERIFICAR DEPENDENCIAS ===
    $dependencies = checkStaffDependencies($conn, $staff_id);
    $has_blocking_dependencies = false;
    
    foreach ($dependencies as $key => $dependency) {
        if ($dependency['blocking']) {
            $has_blocking_dependencies = true;
            break;
        }
    }
    
    // Si hay dependencias bloqueantes y no es forzado, devolver conflicto
    if ($has_blocking_dependencies && !$force) {
        $blocking_messages = [];
        $recommendations = [
            'transfer_departments' => 'Transfiere los departamentos a otro manager',
            'force_delete' => 'Usa eliminación forzada (los departamentos quedarán sin manager)',
            'soft_delete' => 'Desactiva el empleado en lugar de eliminarlo'
        ];
        
        foreach ($dependencies as $key => $dependency) {
            if ($dependency['blocking']) {
                $blocking_messages[] = $dependency['message'];
            }
        }
        
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'El empleado tiene dependencias que impiden su eliminación',
            'errors' => [
                'conflict' => true,
                'dependencies' => $dependencies,
                'blocking_messages' => $blocking_messages,
                'recommendations' => $recommendations
            ],
            'data' => [
                'staff' => $existing_staff,
                'can_delete' => false,
                'dependencies_count' => count($dependencies)
            ]
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // === OBTENER USUARIO ELIMINADOR ===
    $deleted_by = null;
    if (isset($input['deleted_by']) && !empty($input['deleted_by'])) {
        $deleted_by = intval($input['deleted_by']);
    } elseif (isset($_SERVER['HTTP_USER_ID']) && !empty($_SERVER['HTTP_USER_ID'])) {
        $deleted_by = intval($_SERVER['HTTP_USER_ID']);
    }
    
    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);
    
    try {
        // === MANEJAR TRANSFERENCIA DE DEPARTAMENTOS ===
        if (!empty($dependencies['departments']) && $transfer_departments_to) {
            // Verificar que el empleado de destino existe
            $check_target_sql = "SELECT COUNT(*) as count FROM staff WHERE id = ? AND is_active = 1";
            $check_target_stmt = $conn->prepare($check_target_sql);
            $check_target_stmt->bind_param("i", $transfer_departments_to);
            $check_target_stmt->execute();
            $target_result = $check_target_stmt->get_result();
            $target_count = $target_result->fetch_assoc()['count'];
            $check_target_stmt->close();
            
            if ($target_count == 0) {
                throw new Exception("El empleado de destino para transferir departamentos no existe o está inactivo");
            }
            
            // Transferir departamentos
            $transfer_sql = "UPDATE departments SET manager_id = ?, updated_at = NOW() WHERE manager_id = ?";
            $transfer_stmt = $conn->prepare($transfer_sql);
            $transfer_stmt->bind_param("ii", $transfer_departments_to, $staff_id);
            
            if (!$transfer_stmt->execute()) {
                throw new Exception("Error al transferir departamentos: " . $transfer_stmt->error);
            }
            $transfer_stmt->close();
        } elseif (!empty($dependencies['departments']) && $force) {
            // Remover manager de departamentos (forzado)
            $remove_manager_sql = "UPDATE departments SET manager_id = NULL, updated_at = NOW() WHERE manager_id = ?";
            $remove_manager_stmt = $conn->prepare($remove_manager_sql);
            $remove_manager_stmt->bind_param("i", $staff_id);
            
            if (!$remove_manager_stmt->execute()) {
                throw new Exception("Error al remover manager de departamentos: " . $remove_manager_stmt->error);
            }
            $remove_manager_stmt->close();
        }
        
        if ($soft_delete) {
            // === ELIMINACIÓN SUAVE (DESACTIVAR) ===
            $soft_delete_sql = "UPDATE staff SET 
                is_active = 0, 
                updated_at = NOW(),
                updated_by = ?
            WHERE id = ?";
            
            $soft_delete_stmt = $conn->prepare($soft_delete_sql);
            $soft_delete_stmt->bind_param("ii", $deleted_by, $staff_id);
            
            if (!$soft_delete_stmt->execute()) {
                throw new Exception("Error al desactivar empleado: " . $soft_delete_stmt->error);
            }
            
            $affected_rows = $soft_delete_stmt->affected_rows;
            $soft_delete_stmt->close();
            
            if ($affected_rows === 0) {
                throw new Exception("No se pudo desactivar el empleado");
            }
            
            $operation_type = 'deactivated';
            $message = 'Empleado desactivado exitosamente';
            
        } else {
            // === ELIMINACIÓN PERMANENTE ===
            
            // Crear tabla de log si no existe
            $create_log_sql = "CREATE TABLE IF NOT EXISTS staff_deletion_log (
                id INT AUTO_INCREMENT PRIMARY KEY,
                staff_id INT NOT NULL,
                staff_code VARCHAR(20),
                staff_name VARCHAR(255),
                staff_email VARCHAR(255),
                reason TEXT,
                deleted_by INT,
                deleted_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                staff_data JSON
            )";
            $conn->query($create_log_sql);
            
            // Guardar log antes de eliminar
            $log_sql = "INSERT INTO staff_deletion_log 
                (staff_id, staff_code, staff_name, staff_email, reason, deleted_by, staff_data) 
                VALUES (?, ?, ?, ?, ?, ?, ?)";
            
            $staff_data_json = json_encode($existing_staff);
            $staff_name = $existing_staff['first_name'] . ' ' . $existing_staff['last_name'];
            
            $log_stmt = $conn->prepare($log_sql);
            $log_stmt->bind_param(
                "issssis",
                $staff_id,
                $existing_staff['staff_code'],
                $staff_name,
                $existing_staff['email'],
                $reason,
                $deleted_by,
                $staff_data_json
            );
            
            if (!$log_stmt->execute()) {
                throw new Exception("Error al crear log de eliminación: " . $log_stmt->error);
            }
            $log_stmt->close();
            
            // Eliminar empleado permanentemente
            $delete_sql = "DELETE FROM staff WHERE id = ?";
            $delete_stmt = $conn->prepare($delete_sql);
            $delete_stmt->bind_param("i", $staff_id);
            
            if (!$delete_stmt->execute()) {
                throw new Exception("Error al eliminar empleado: " . $delete_stmt->error);
            }
            
            $affected_rows = $delete_stmt->affected_rows;
            $delete_stmt->close();
            
            if ($affected_rows === 0) {
                throw new Exception("No se pudo eliminar el empleado");
            }
            
            $operation_type = 'deleted';
            $message = 'Empleado eliminado permanentemente';
        }
        
        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();
        
        // === RESPUESTA EXITOSA ===
        $response_data = [
            'operation' => $operation_type,
            'staff_id' => $staff_id,
            'staff_code' => $existing_staff['staff_code'],
            'staff_name' => $existing_staff['first_name'] . ' ' . $existing_staff['last_name'],
            'reason' => $reason
        ];
        
        if (!empty($dependencies)) {
            $response_data['dependencies_handled'] = $dependencies;
        }
        
        if ($transfer_departments_to) {
            $response_data['departments_transferred_to'] = $transfer_departments_to;
        }
        
        if (!$soft_delete) {
            $response_data['backup_created'] = true;
        }
        
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => $message,
            'data' => $response_data
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        // Revertir transacción
        $conn->rollback();
        throw $e;
    } finally {
        // Restaurar autocommit
        $conn->autocommit(true);
    }
    
} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
?>