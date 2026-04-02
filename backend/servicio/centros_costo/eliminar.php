<?php
/**
 * POST /API_Infoapp/servicio/centros_costo/eliminar.php
 * 
 * Endpoint para eliminar (desactivar) un centro de costo
 * Requiere autenticación JWT
 */

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/centros_costo/eliminar.php', 'delete_centro_costo');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../../conexion.php';
    
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // PASO 5: Obtener datos del body
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);
    
    if (!$data || !isset($data['nombre'])) {
        sendJsonResponse(errorResponse('Nombre del centro de costo es requerido'), 400);
    }
    
    $nombre = trim($data['nombre']);
    
    // Verificar si está en uso
    $check_stmt = $conn->prepare(
        "SELECT COUNT(*) as total FROM servicios WHERE centro_costo = ? AND anular_servicio = 0"
    );
    $check_stmt->bind_param('s', $nombre);
    $check_stmt->execute();
    $result = $check_stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row['total'] > 0) {
        sendJsonResponse(
            errorResponse("No se puede eliminar: hay {$row['total']} servicio(s) activo(s) usando este centro de costo"),
            400
        );
    }
    
    // Desactivar centro de costo
    $stmt = $conn->prepare("UPDATE centros_costo SET activo = 0 WHERE LOWER(nombre) = LOWER(?)");
    $stmt->bind_param('s', $nombre);
    
    if (!$stmt->execute()) {
        throw new Exception("Error al eliminar centro de costo: " . $stmt->error);
    }
    
    if ($stmt->affected_rows === 0) {
        sendJsonResponse(errorResponse('Centro de costo no encontrado'), 404);
    }
    
    sendJsonResponse([
        'success' => true,
        'message' => 'Centro de costo eliminado exitosamente',
        'deleted_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>