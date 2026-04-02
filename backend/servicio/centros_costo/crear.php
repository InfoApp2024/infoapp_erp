<?php
/**
 * POST /API_Infoapp/servicio/centros_costo/crear.php
 * 
 * Endpoint para crear un nuevo centro de costo
 * Requiere autenticación JWT
 */

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/centros_costo/crear.php', 'create_centro_costo');
    
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
    
    if (strlen($nombre) < 3) {
        sendJsonResponse(errorResponse('El nombre debe tener al menos 3 caracteres'), 400);
    }
    
    // Verificar si ya existe
    $check_stmt = $conn->prepare("SELECT id FROM centros_costo WHERE LOWER(nombre) = LOWER(?)");
    $check_stmt->bind_param('s', $nombre);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        sendJsonResponse(errorResponse('Este centro de costo ya existe'), 400);
    }
    
    // Insertar nuevo centro
    $stmt = $conn->prepare("INSERT INTO centros_costo (nombre, descripcion) VALUES (?, ?)");
    $descripcion = isset($data['descripcion']) ? $data['descripcion'] : null;
    $stmt->bind_param('ss', $nombre, $descripcion);
    
    if (!$stmt->execute()) {
        throw new Exception("Error al crear centro de costo: " . $stmt->error);
    }
    
    sendJsonResponse([
        'success' => true,
        'message' => 'Centro de costo creado exitosamente',
        'id' => $conn->insert_id,
        'nombre' => $nombre,
        'created_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ], 201);
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>