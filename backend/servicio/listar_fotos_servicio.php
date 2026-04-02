<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/listar_fotos_servicio.php', 'view_photos');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Validar parámetros
    $servicio_id = $_GET['servicio_id'] ?? null;
    
    if (!$servicio_id) {
        throw new Exception('servicio_id es requerido');
    }
    
    // PASO 6: Validar que el servicio existe
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE id = ?");
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();
    
    if ($row['count'] == 0) {
        throw new Exception('Servicio no encontrado');
    }
    
    // PASO 7: Obtener fotos del servicio
    $stmt = $conn->prepare("
        SELECT 
            id,
            tipo_foto,
            nombre_archivo,
            ruta_archivo,
            descripcion,
            fecha_subida,
            orden_visualizacion,
            tamaño_bytes
        FROM fotos_servicio 
        WHERE servicio_id = ? 
        ORDER BY tipo_foto, orden_visualizacion, fecha_subida
    ");
    
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $fotos = [];
    while ($row = $result->fetch_assoc()) {
        $fotos[] = [
            'id' => intval($row['id']),
            'tipo_foto' => $row['tipo_foto'],
            'nombre_archivo' => $row['nombre_archivo'],
            'ruta_archivo' => $row['ruta_archivo'],
            'descripcion' => $row['descripcion'],
            'fecha_subida' => $row['fecha_subida'],
            'orden_visualizacion' => intval($row['orden_visualizacion']),
            'tamaño_bytes' => intval($row['tamaño_bytes'])
        ];
    }
    
    // PASO 8: Respuesta con contexto de usuario
    sendJsonResponse([
        'success' => true,
        'servicio_id' => intval($servicio_id),
        'fotos' => $fotos,
        'total_fotos' => count($fotos),
        'fotos_antes' => count(array_filter($fotos, fn($f) => $f['tipo_foto'] === 'antes')),
        'fotos_despues' => count(array_filter($fotos, fn($f) => $f['tipo_foto'] === 'despues')),
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
?>