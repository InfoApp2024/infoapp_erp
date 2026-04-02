<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/eliminar_funcionario.php', 'delete_funcionario');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Leer y validar input
    $data = json_decode(file_get_contents("php://input"));
    
    if (!$data || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }
    
    if (!isset($data->funcionario_id)) {
        throw new Exception('ID del funcionario es obligatorio');
    }
    
    $funcionario_id = intval($data->funcionario_id);
    
    if ($funcionario_id <= 0) {
        throw new Exception('ID del funcionario debe ser un número válido');
    }
    
    // PASO 6: Verificar que el funcionario existe y está activo
    $stmt = $conn->prepare("SELECT nombre, activo FROM funcionario WHERE id = ?");
    $stmt->bind_param("i", $funcionario_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $funcionario = $result->fetch_assoc();
    $stmt->close();
    
    if (!$funcionario) {
        throw new Exception('Funcionario no encontrado');
    }
    
    if ($funcionario['activo'] == 0) {
        throw new Exception('El funcionario ya está inactivo');
    }
    
    // PASO 7: Verificar si el funcionario tiene servicios asociados
    $stmt = $conn->prepare("SELECT COUNT(*) as servicios_count FROM servicios WHERE autorizado_por = ?");
    $stmt->bind_param("i", $funcionario_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $servicios_info = $result->fetch_assoc();
    $stmt->close();
    
    $servicios_asociados = (int)$servicios_info['servicios_count'];
    
    // PASO 8: Desactivar funcionario (no eliminación física)
    $stmt = $conn->prepare("
        UPDATE funcionario 
        SET activo = 0, 
            fecha_inactivacion = NOW(),
            usuario_inactivacion = ?
        WHERE id = ?
    ");
    $stmt->bind_param("ii", $currentUser['id'], $funcionario_id);
    
    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        $stmt->close();
        
        // PASO 9: Respuesta exitosa con contexto de usuario
        sendJsonResponse([
            'success' => true,
            'message' => "Funcionario '{$funcionario['nombre']}' desactivado correctamente",
            'data' => [
                'funcionario_id' => $funcionario_id,
                'nombre' => $funcionario['nombre'],
                'servicios_asociados' => $servicios_asociados,
                'affected_rows' => $affected_rows,
                'deleted_by_user' => $currentUser['usuario'],
                'deleted_by_role' => $currentUser['rol']
            ]
        ]);
        
    } else {
        throw new Exception('Error al desactivar el funcionario: ' . $stmt->error);
    }
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($stmt) && $stmt !== null) {
    $stmt->close();
}
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>