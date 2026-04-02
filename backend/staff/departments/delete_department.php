<?php
/**
 * DELETE /API_Infoapp/staff/departments/delete_department.php
 * 
 * Endpoint para eliminar un departamento (soft delete) - VERSIÓN SIMPLIFICADA
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
    // Incluir archivo de conexión
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
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

    // === VALIDACIÓN DE ID REQUERIDO ===
    if (!isset($data['id']) || !is_numeric($data['id'])) {
        sendErrorResponse(400, 'ID de departamento requerido y debe ser numérico');
    }

    $department_id = intval($data['id']);
    $deleted_by = isset($data['deleted_by']) && is_numeric($data['deleted_by']) ? intval($data['deleted_by']) : null;
    $reason = isset($data['reason']) ? trim($data['reason']) : 'Eliminado vía API';

    // === VERIFICAR QUE EL DEPARTAMENTO EXISTE ===
    $check_sql = "SELECT id, name, description, manager_id, is_active FROM departments WHERE id = ? AND deleted_at IS NULL";
    $check_stmt = $conn->prepare($check_sql);
    
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de verificación: ' . $conn->error);
    }

    $check_stmt->bind_param('i', $department_id);
    
    if (!$check_stmt->execute()) {
        sendErrorResponse(500, 'Error ejecutando consulta de verificación: ' . $check_stmt->error);
    }

    $check_result = $check_stmt->get_result();
    if ($check_result->num_rows === 0) {
        $check_stmt->close();
        sendErrorResponse(404, 'Departamento no encontrado', [
            'department_id' => $department_id,
            'message' => 'El departamento no existe o ya fue eliminado'
        ]);
    }

    $department_data = $check_result->fetch_assoc();
    $check_stmt->close();

    // === VERIFICAR SI TIENE EMPLEADOS ACTIVOS (SOLO SI TABLA STAFF EXISTE) ===
    $staff_table_check = $conn->query("SHOW TABLES LIKE 'staff'");
    $has_active_employees = false;
    
    if ($staff_table_check && $staff_table_check->num_rows > 0) {
        $employee_check_sql = "SELECT COUNT(*) as count FROM staff WHERE department_id = ? AND is_active = 1 AND deleted_at IS NULL";
        $employee_stmt = $conn->prepare($employee_check_sql);
        
        if ($employee_stmt) {
            $employee_stmt->bind_param('i', $department_id);
            $employee_stmt->execute();
            $employee_result = $employee_stmt->get_result();
            $employee_count = $employee_result->fetch_assoc()['count'];
            $employee_stmt->close();
            
            if ($employee_count > 0) {
                $has_active_employees = true;
                sendErrorResponse(422, 'No se puede eliminar el departamento', [
                    'reason' => 'El departamento tiene empleados activos asignados',
                    'active_employees' => $employee_count,
                    'suggestion' => 'Primero reasigne los empleados a otro departamento'
                ]);
            }
        }
    }

    // === PROCEDER CON LA ELIMINACIÓN (SOFT DELETE) ===
    $delete_sql = "UPDATE departments SET deleted_at = NOW(), is_active = 0, updated_at = NOW() WHERE id = ? AND deleted_at IS NULL";
    $delete_stmt = $conn->prepare($delete_sql);
    
    if (!$delete_stmt) {
        sendErrorResponse(500, 'Error preparando eliminación: ' . $conn->error);
    }

    $delete_stmt->bind_param('i', $department_id);
    
    if (!$delete_stmt->execute()) {
        sendErrorResponse(500, 'Error ejecutando eliminación: ' . $delete_stmt->error);
    }

    if ($delete_stmt->affected_rows === 0) {
        $delete_stmt->close();
        sendErrorResponse(400, 'No se pudo eliminar el departamento', [
            'reason' => 'El departamento ya fue eliminado o no existe'
        ]);
    }

    $delete_stmt->close();

    // === REGISTRAR EN AUDITORÍA (SI LA TABLA EXISTE) ===
    $audit_table_check = $conn->query("SHOW TABLES LIKE 'departments_audit_log'");
    if ($audit_table_check && $audit_table_check->num_rows > 0 && $deleted_by !== null) {
        $audit_sql = "INSERT INTO departments_audit_log (department_id, action, old_values, reason, changed_by, ip_address, created_at) 
                      VALUES (?, 'deleted', ?, ?, ?, ?, NOW())";
        
        $audit_stmt = $conn->prepare($audit_sql);
        if ($audit_stmt) {
            $old_values_json = json_encode($department_data);
            $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
            
            $audit_stmt->bind_param('issis', $department_id, $old_values_json, $reason, $deleted_by, $ip_address);
            $audit_stmt->execute();
            $audit_stmt->close();
        }
    }

    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => "Departamento '{$department_data['name']}' eliminado exitosamente",
        'data' => [
            'deleted_department' => [
                'id' => intval($department_data['id']),
                'name' => $department_data['name'],
                'description' => $department_data['description'],
                'was_active' => boolval($department_data['is_active'])
            ],
            'deletion_info' => [
                'deleted_by' => $deleted_by,
                'reason' => $reason,
                'deletion_timestamp' => date('Y-m-d H:i:s'),
                'can_be_restored' => true
            ]
        ]
    ], JSON_UNESCAPED_UNICODE);

} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
} finally {
    // Cerrar conexión
    if (isset($conn)) {
        $conn->close();
    }
}
?>