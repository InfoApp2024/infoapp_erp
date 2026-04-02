<?php
/**
 * DELETE /servicio_staff/eliminar.php
 * 
 * Endpoint para eliminar un usuario específico de un servicio
 * Adaptado para trabajar con tabla `usuarios` en lugar de `staff`
 * Requiere autenticación JWT
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

header('Content-Type: application/json; charset=utf-8');
// header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/servicio_staff/eliminar.php', 'delete_service_staff');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        sendJsonResponse(errorResponse('Método no permitido. Use DELETE'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../../conexion.php';
    
    // PASO 5: Obtener datos del body
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $data = [];
    
    if (strpos($contentType, 'application/json') !== false) {
        $json = file_get_contents('php://input');
        $data = json_decode($json, true);
    } else {
        $data = !empty($_POST) ? $_POST : $_GET;
    }
    
    if (!$data) {
        sendJsonResponse(errorResponse('No se recibieron datos'), 400);
    }
    
    // PASO 6: Validar parámetros - Acepta dos formas
    $servicio_staff_id = isset($data['servicio_staff_id']) ? intval($data['servicio_staff_id']) : null;
    $servicio_id = isset($data['servicio_id']) ? intval($data['servicio_id']) : null;
    $usuario_id = isset($data['usuario_id']) ? intval($data['usuario_id']) : null;
    
    // Legacy: staff_id (lo mapeamos a usuario_id)
    if (!$usuario_id && isset($data['staff_id'])) {
        $usuario_id = intval($data['staff_id']);
    }

    $validarEstadoServicio = function($id, $conn, $currentUser) {
        $sqlState = "SELECT eb.nombre as estado_base_nombre, eb.codigo as estado_base_codigo, eb.permite_edicion
                    FROM servicios s
                    JOIN estados_proceso ep ON s.estado = ep.id
                    JOIN estados_base eb ON ep.estado_base_codigo = eb.codigo
                    WHERE s.id = ? LIMIT 1";
        $stmtState = $conn->prepare($sqlState);
        $stmtState->bind_param("i", $id);
        $stmtState->execute();
        $resState = $stmtState->get_result();
        $baseInfo = $resState->fetch_assoc();
        $stmtState->close();

        if ($baseInfo) {
            $estadoCodigo = $baseInfo['estado_base_codigo'];
            $isTerminal = in_array($estadoCodigo, ['LEGALIZADO', 'CANCELADO']);
            $permiteEdicion = (int)$baseInfo['permite_edicion'];

            // Si es terminal, BLOQUEO ABSOLUTO
            if ($isTerminal) {
                sendJsonResponse(errorResponse("No se puede gestionar el personal. El servicio está en estado final ($estadoCodigo). Debe solicitar el retorno desde Gestión Financiera."), 403);
            }

            // Si NO permite edición (y no es terminal), verificar bypass
            if ($permiteEdicion === 0) {
                $sqlPerm = "SELECT can_edit_closed_ops FROM usuarios WHERE id = ? LIMIT 1";
                $stmtPerm = $conn->prepare($sqlPerm);
                $stmtPerm->bind_param("i", $currentUser['id']);
                $stmtPerm->execute();
                $resPerm = $stmtPerm->get_result();
                $canEdit = false;
                if ($rowPerm = $resPerm->fetch_assoc()) {
                    $canEdit = ((int)$rowPerm['can_edit_closed_ops'] === 1);
                }
                $stmtPerm->close();

                if (!$canEdit) {
                    sendJsonResponse(errorResponse("No tienes permiso para modificar el personal en este estado ({$baseInfo['estado_base_nombre']})."), 403);
                }
            }
        }
    };
    
    // OPCIÓN 1: Eliminar por ID de la tabla pivot (servicio_staff)
    if ($servicio_staff_id && $servicio_staff_id > 0) {
        
        // Verificar que existe la asignación
        $sqlCheck = "
            SELECT 
                ss.id, 
                ss.servicio_id, 
                ss.staff_id,
                u.NOMBRE_USER,
                u.NOMBRE_CLIENTE,
                CONCAT(u.NOMBRE_USER, ' ', COALESCE(u.NOMBRE_CLIENTE, '')) as usuario_nombre
            FROM servicio_staff ss
            INNER JOIN usuarios u ON ss.staff_id = u.id
            WHERE ss.id = ?
            LIMIT 1
        ";
        
        $stmtCheck = $conn->prepare($sqlCheck);
        if (!$stmtCheck) {
            throw new Exception('Error preparando consulta: ' . $conn->error);
        }
        
        $stmtCheck->bind_param('i', $servicio_staff_id);
        $stmtCheck->execute();
        $resultCheck = $stmtCheck->get_result();
        
        if ($resultCheck->num_rows === 0) {
            sendJsonResponse(errorResponse('Asignación no encontrada'), 404);
        }
        
        $asignacion = $resultCheck->fetch_assoc();
        $stmtCheck->close();

        // ✅ VALIDAR ESTADO
        $validarEstadoServicio((int)$asignacion['servicio_id'], $conn, $currentUser);
        
        // Eliminar la asignación
        $sqlDelete = "DELETE FROM servicio_staff WHERE id = ?";
        $stmtDelete = $conn->prepare($sqlDelete);
        $stmtDelete->bind_param('i', $servicio_staff_id);
        
        if (!$stmtDelete->execute()) {
            throw new Exception('Error eliminando asignación: ' . $stmtDelete->error);
        }
        $stmtDelete->close();
        
        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => 'Usuario eliminado del servicio exitosamente',
            'data' => [
                'servicio_staff_id' => intval($asignacion['id']),
                'servicio_id' => intval($asignacion['servicio_id']),
                'usuario_eliminado' => [
                    'usuario_id' => intval($asignacion['staff_id']),
                    'nombre' => $asignacion['NOMBRE_USER'] ?? '',
                    'apellido' => $asignacion['NOMBRE_CLIENTE'] ?? '',
                    'full_name' => $asignacion['usuario_nombre']
                ]
            ],
            'deleted_by' => $currentUser['usuario']
        ], 200);
    }
    
    // OPCIÓN 2: Eliminar por servicio_id + usuario_id
    elseif ($servicio_id && $servicio_id > 0 && $usuario_id && $usuario_id > 0) {
        
        // Verificar que existe el servicio
        $sqlServiceCheck = "SELECT id FROM servicios WHERE id = ? LIMIT 1";
        $stmtServiceCheck = $conn->prepare($sqlServiceCheck);
        $stmtServiceCheck->bind_param('i', $servicio_id);
        $stmtServiceCheck->execute();
        
        if ($stmtServiceCheck->get_result()->num_rows === 0) {
            sendJsonResponse(errorResponse('Servicio no encontrado'), 404);
        }
        $stmtServiceCheck->close();

        // ✅ VALIDAR ESTADO
        $validarEstadoServicio($servicio_id, $conn, $currentUser);
        
        // Verificar que existe la asignación
        $sqlCheckAsign = "
            SELECT 
                ss.id,
                u.NOMBRE_USER,
                u.NOMBRE_CLIENTE,
                CONCAT(u.NOMBRE_USER, ' ', COALESCE(u.NOMBRE_CLIENTE, '')) as usuario_nombre
            FROM servicio_staff ss
            INNER JOIN usuarios u ON ss.staff_id = u.id
            WHERE ss.servicio_id = ? AND ss.staff_id = ?
            LIMIT 1
        ";
        
        $stmtCheckAsign = $conn->prepare($sqlCheckAsign);
        $stmtCheckAsign->bind_param('ii', $servicio_id, $usuario_id);
        $stmtCheckAsign->execute();
        $resultCheckAsign = $stmtCheckAsign->get_result();
        
        if ($resultCheckAsign->num_rows === 0) {
            sendJsonResponse(errorResponse('El usuario no está asignado a este servicio'), 404);
        }
        
        $asignacion = $resultCheckAsign->fetch_assoc();
        $stmtCheckAsign->close();
        
        // Eliminar la asignación
        $sqlDelete = "DELETE FROM servicio_staff WHERE servicio_id = ? AND staff_id = ?";
        $stmtDelete = $conn->prepare($sqlDelete);
        $stmtDelete->bind_param('ii', $servicio_id, $usuario_id);
        
        if (!$stmtDelete->execute()) {
            throw new Exception('Error eliminando asignación: ' . $stmtDelete->error);
        }
        $stmtDelete->close();
        
        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => 'Usuario eliminado del servicio exitosamente',
            'data' => [
                'servicio_staff_id' => intval($asignacion['id']),
                'servicio_id' => $servicio_id,
                'usuario_eliminado' => [
                    'usuario_id' => $usuario_id,
                    'nombre' => $asignacion['NOMBRE_USER'] ?? '',
                    'apellido' => $asignacion['NOMBRE_CLIENTE'] ?? '',
                    'full_name' => $asignacion['usuario_nombre']
                ]
            ],
            'deleted_by' => $currentUser['usuario']
        ], 200);
    }
    
    // Parámetros inválidos
    else {
        sendJsonResponse(
            errorResponse('Parámetros inválidos. Envía: servicio_staff_id O (servicio_id + usuario_id)'),
            400
        );
    }
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>