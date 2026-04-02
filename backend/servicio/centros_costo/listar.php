<?php
/**
 * GET /API_Infoapp/servicio/centros_costo/listar.php
 * 
 * Endpoint para obtener todos los centros de costo activos
 * Requiere autenticación JWT
 */

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/centros_costo/listar.php', 'view_centros_costo');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../../conexion.php';
    
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    $sql = "SELECT nombre FROM centros_costo WHERE activo = 1 ORDER BY nombre ASC";
    $result = $conn->query($sql);
    
    if (!$result) {
        throw new Exception("Error en consulta: " . $conn->error);
    }
    
    $centros = [];
    while ($row = $result->fetch_assoc()) {
        $centros[] = strtolower($row['nombre']);
    }
    
    sendJsonResponse([
        'success' => true,
        'centros' => $centros,
        'total' => count($centros),
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>