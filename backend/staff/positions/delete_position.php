<?php
/**
 * DELETE /API_Infoapp/staff/positions/delete_position.php
 * 
 * Endpoint para eliminar una posición/cargo (soft delete)
 * Incluye validaciones de integridad y registro de auditoría
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
    $deleted_by = isset($data['deleted_by']) && is_numeric($data['deleted_by']) ? intval($data['deleted_by']) : null;
    $reason = isset($data['reason']) ? trim($data['reason']) : 'Eliminado vía API';

    // === VERIFICAR QUE LA POSICIÓN EXISTE Y OBTENER INFORMACIÓN COMPLETA ===
    if ($tables_check['departments'] && $tables_check['staff']) {
        // Consulta completa con todas las tablas
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
            COUNT(DISTINCT s.id) as total_employees,
            COUNT(DISTINCT sa.id) as active_employees,
            COUNT(DISTINCT si.id) as inactive_employees
        FROM positions p
        LEFT JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL
        LEFT JOIN staff s ON p.id = s.position_id AND s.deleted_at IS NULL
        LEFT JOIN staff sa ON p.id = sa.position_id AND sa.deleted_at IS NULL AND sa.is_active = 1
        LEFT JOIN staff si ON p.id = si.position_id AND si.deleted_at IS NULL AND si.is_active = 0
        WHERE p.id = ? AND p.deleted_at IS NULL
        GROUP BY p.id";
    } elseif ($tables_check['departments']) {
        // Solo con departments
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
            0 as total_employees,
            0 as active_employees,
            0 as inactive_employees
        FROM positions p
        LEFT JOIN departments d ON p.department_id = d.id AND d.deleted_at IS NULL
        WHERE p.id = ? AND p.deleted_at IS NULL";
    } else {
        // Solo positions
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
            CONCAT('Departamento ', p.department_id) as department_name,
            0 as total_employees,
            0 as active_employees,
            0 as inactive_employees
        FROM positions p
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
            'message' => 'La posición no existe o ya fue eliminada'
        ]);
    }

    $position_data = $check_result->fetch_assoc();
    $check_stmt->close();

    // === VALIDACIONES DE INTEGRIDAD ANTES DE ELIMINAR ===
    $blocking_issues = [];
    $warnings = [];

    // Verificar empleados activos (solo si tabla staff existe)
    $active_employees = intval($position_data['active_employees']);
    if ($active_employees > 0 && $tables_check['staff']) {
        $blocking_issues['active_employees'] = "La posición tiene {$active_employees} empleado(s) activo(s) asignado(s)";
    }

    // Verificar empleados inactivos (advertencia, no bloquea)
    $inactive_employees = intval($position_data['inactive_employees']);
    if ($inactive_employees > 0 && $tables_check['staff']) {
        $warnings['inactive_employees'] = "La posición tiene {$inactive_employees} empleado(s) inactivo(s) que serán reasignados";
    }

    // Si hay problemas que bloquean la eliminación
    if (!empty($blocking_issues)) {
        sendErrorResponse(422, 'No se puede eliminar la posición debido a dependencias', [
            'blocking_issues' => $blocking_issues,
            'warnings' => $warnings,
            'suggestion' => 'Primero reasigne los empleados activos a otra posición',
            'position_info' => [
                'title' => $position_data['title'],
                'department_name' => $position_data['department_name'],
                'active_employees' => $active_employees,
                'inactive_employees' => $inactive_employees,
                'total_employees' => intval($position_data['total_employees'])
            ],
            'tables_available' => $tables_check
        ]);
    }

    // === PROCEDER CON LA ELIMINACIÓN (SOFT DELETE) ===
    $conn->autocommit(false);

    try {
        // Preparar datos para auditoría
        $position_snapshot = [
            'id' => intval($position_data['id']),
            'title' => $position_data['title'],
            'description' => $position_data['description'],
            'department_id' => intval($position_data['department_id']),
            'department_name' => $position_data['department_name'],
            'min_salary' => $position_data['min_salary'] ? floatval($position_data['min_salary']) : null,
            'max_salary' => $position_data['max_salary'] ? floatval($position_data['max_salary']) : null,
            'is_active' => boolval($position_data['is_active']),
            'total_employees' => intval($position_data['total_employees']),
            'active_employees' => $active_employees,
            'inactive_employees' => $inactive_employees,
            'created_at' => $position_data['created_at'],
            'updated_at' => $position_data['updated_at']
        ];

        // === REASIGNAR EMPLEADOS INACTIVOS SI LOS HAY ===
        if ($inactive_employees > 0 && $tables_check['staff']) {
            // Buscar una posición "Sin Asignar" o "General" en el mismo departamento
            $default_pos_sql = "SELECT id FROM positions 
                               WHERE LOWER(title) IN ('sin asignar', 'no asignado', 'general', 'auxiliar') 
                               AND department_id = ? AND is_active = 1 AND deleted_at IS NULL 
                               AND id != ? 
                               LIMIT 1";
            
            $default_pos_stmt = $conn->prepare($default_pos_sql);
            $default_position_id = null;
            
            if ($default_pos_stmt) {
                $default_pos_stmt->bind_param('ii', $position_data['department_id'], $position_id);
                $default_pos_stmt->execute();
                $default_pos_result = $default_pos_stmt->get_result();
                
                if ($default_pos_result->num_rows > 0) {
                    $default_position_id = $default_pos_result->fetch_assoc()['id'];
                }
                $default_pos_stmt->close();
            }

            if ($default_position_id) {
                $reassign_sql = "UPDATE staff SET position_id = ?, updated_at = NOW() 
                               WHERE position_id = ? AND is_active = 0 AND deleted_at IS NULL";
                $reassign_stmt = $conn->prepare($reassign_sql);
                
                if ($reassign_stmt) {
                    $reassign_stmt->bind_param('ii', $default_position_id, $position_id);
                    $reassign_stmt->execute();
                    $reassigned_count = $reassign_stmt->affected_rows;
                    $reassign_stmt->close();
                    
                    if ($reassigned_count > 0) {
                        $warnings['employees_reassigned'] = "Se reasignaron {$reassigned_count} empleado(s) inactivo(s) a otra posición";
                    }
                }
            } else {
                // Si no hay posición por defecto, crear una advertencia
                $warnings['employees_need_reassignment'] = "Los {$inactive_employees} empleado(s) inactivo(s) necesitarán reasignación manual";
            }
        }

        // === SOFT DELETE DE LA POSICIÓN ===
        $delete_sql = "UPDATE positions SET deleted_at = NOW(), is_active = 0, updated_at = NOW() WHERE id = ?";
        $delete_stmt = $conn->prepare($delete_sql);
        
        if (!$delete_stmt) {
            throw new Exception('Error preparando eliminación: ' . $conn->error);
        }

        $delete_stmt->bind_param('i', $position_id);
        
        if (!$delete_stmt->execute()) {
            throw new Exception('Error ejecutando eliminación: ' . $delete_stmt->error);
        }

        if ($delete_stmt->affected_rows === 0) {
            throw new Exception('No se pudo eliminar la posición');
        }

        $delete_stmt->close();

        // === REGISTRAR AUDITORÍA (solo si tabla existe) ===
        if ($deleted_by !== null) {
            $audit_table_check = $conn->query("SHOW TABLES LIKE 'positions_audit_log'");
            
            if ($audit_table_check && $audit_table_check->num_rows > 0) {
                $audit_sql = "INSERT INTO positions_audit_log (position_id, action, old_values, reason, changed_by, ip_address, created_at) 
                              VALUES (?, 'deleted', ?, ?, ?, ?, NOW())";
                
                $audit_stmt = $conn->prepare($audit_sql);
                if ($audit_stmt) {
                    $old_values_json = json_encode($position_snapshot);
                    $ip_address = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
                    
                    $audit_stmt->bind_param('issis', $position_id, $old_values_json, $reason, $deleted_by, $ip_address);
                    $audit_stmt->execute();
                    $audit_stmt->close();
                }
            }
        }

        // Confirmar transacción
        $conn->commit();

        // === INFORMACIÓN DE LA ELIMINACIÓN ===
        $deletion_info = [
            'position_deleted' => true,
            'deleted_by' => $deleted_by,
            'deletion_timestamp' => date('Y-m-d H:i:s'),
            'reason' => $reason,
            'cleanup_actions' => [],
            'warnings' => $warnings,
            'tables_available' => $tables_check
        ];

        if ($inactive_employees > 0 && $tables_check['staff']) {
            if (isset($reassigned_count) && $reassigned_count > 0) {
                $deletion_info['cleanup_actions'][] = "Empleados inactivos reasignados automáticamente";
            } else {
                $deletion_info['cleanup_actions'][] = "Empleados inactivos requieren reasignación manual";
            }
        }

        // === RESPUESTA EXITOSA ===
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => "Posición '{$position_data['title']}' eliminada exitosamente",
            'data' => [
                'deleted_position' => $position_snapshot,
                'deletion_info' => $deletion_info
            ]
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