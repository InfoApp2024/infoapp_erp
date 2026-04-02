<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/eliminar_equipos.php', 'delete_equipments');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Obtener datos del request
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input || empty($input['id'])) {
        sendJsonResponse(errorResponse('ID del equipo es requerido'), 400);
    }
    
    $id = (int)$input['id'];
    
    // PASO 6: Verificar que el equipo existe
    $stmt = $conn->prepare("SELECT id, nombre FROM equipos WHERE id = ? AND activo = 1");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $equipo = $result->fetch_assoc();
    $stmt->close();
    
    if (!$equipo) {
        sendJsonResponse(errorResponse('El equipo no existe o ya está eliminado'), 404);
    }
    
    // PASO 7: (Opcional) Verificar si tiene servicios asociados
    /*
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE equipo_id = ? AND activo = 1");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    $stmt->close();
    
    if ($row['count'] > 0) {
        sendJsonResponse(errorResponse('No se puede eliminar el equipo porque tiene servicios asociados'), 409);
    }
    */
    
    // PASO 8: Soft delete - marcar como inactivo
    // No cambiamos estado_id, solo marcamos activo = 0
    $stmt = $conn->prepare("UPDATE equipos SET activo = 0 WHERE id = ?");
    $stmt->bind_param("i", $id);
    
    if ($stmt->execute()) {
        $stmt->close();
        
        sendJsonResponse([
            'success' => true,
            'message' => 'Equipo eliminado exitosamente',
            'id' => $id,
            'nombre_equipo' => $equipo['nombre'],
            'usuario_registro' => $currentUser['usuario'],
            'user_role' => $currentUser['rol']
        ]);
    } else {
        $stmt->close();
        sendJsonResponse(errorResponse('Error al eliminar el equipo: ' . $stmt->error), 500);
    }
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>