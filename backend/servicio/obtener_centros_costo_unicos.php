<?php
/**
 * GET /API_Infoapp/servicio/obtener_centros_costo_unicos.php
 * 
 * Obtiene valores únicos de centro_costo desde servicios
 * Requiere autenticación JWT
 */

require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/obtener_centros_costo_unicos.php', 'view_centros_costo');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Obtener valores únicos de centro_costo desde servicios
    $stmt = $conn->prepare("
        SELECT DISTINCT LOWER(TRIM(centro_costo)) as centro 
        FROM servicios 
        WHERE centro_costo IS NOT NULL 
        AND centro_costo != '' 
        AND anular_servicio = 0
        ORDER BY centro ASC
    ");
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $centros = [];
    while ($row = $result->fetch_assoc()) {
        $centroLimpio = trim(strtolower($row['centro']));
        if (!empty($centroLimpio)) {
            $centros[] = $centroLimpio;
        }
    }
    
    // Asegurar que los centros por defecto estén incluidos si no hay datos
    if (empty($centros)) {
        $centros = ['producción', 'mantenimiento', 'administración'];
    }
    
    // Remover duplicados
    $centros = array_unique($centros);
    
    sendJsonResponse([
        'success' => true,
        'centros' => array_values($centros),
        'total' => count($centros),
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);
    
} catch (Exception $e) {
    error_log("obtener_centros_costo_unicos.php - Error: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error obteniendo centros de costo: ' . $e->getMessage()), 500);
}

if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
?>