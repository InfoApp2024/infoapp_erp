<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/obtener_funcionario.php', 'view_funcionario_details');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Validar parámetros
    $funcionario_id = $_GET['id'] ?? $_GET['funcionario_id'] ?? null;
    
    if (!$funcionario_id) {
        throw new Exception('ID del funcionario es requerido');
    }
    
    if (!is_numeric($funcionario_id) || $funcionario_id <= 0) {
        throw new Exception('ID del funcionario debe ser un número válido');
    }
    
    // PASO 6: Obtener funcionario con estadísticas
    $stmt = $conn->prepare("
        SELECT 
            f.*,
            COUNT(s.id) as total_servicios,
            COUNT(CASE WHEN s.anular_servicio = 0 THEN 1 END) as servicios_activos,
            COUNT(CASE WHEN s.anular_servicio = 1 THEN 1 END) as servicios_anulados,
            MAX(s.fecha_registro) as ultimo_servicio_fecha
        FROM funcionario f
        LEFT JOIN servicios s ON f.id = s.autorizado_por
        WHERE f.id = ? AND f.activo = 1
        GROUP BY f.id, f.nombre, f.cargo, f.empresa, f.activo, f.fecha_creacion
    ");
    
    $stmt->bind_param("i", $funcionario_id);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows > 0) {
        $funcionario = $result->fetch_assoc();
        $stmt->close();
        
        // PASO 7: Formatear datos para la respuesta
        $funcionario_formateado = [
            'id' => (int)$funcionario['id'],
            'nombre' => $funcionario['nombre'],
            'cargo' => $funcionario['cargo'],
            'empresa' => $funcionario['empresa'],
            'activo' => (bool)$funcionario['activo'],
            'fecha_creacion' => $funcionario['fecha_creacion'],
            'estadisticas' => [
                'total_servicios' => (int)$funcionario['total_servicios'],
                'servicios_activos' => (int)$funcionario['servicios_activos'],
                'servicios_anulados' => (int)$funcionario['servicios_anulados'],
                'ultimo_servicio_fecha' => $funcionario['ultimo_servicio_fecha']
            ]
        ];
        
        // PASO 8: Respuesta exitosa con contexto de usuario
        sendJsonResponse([
            'success' => true,
            'funcionario' => $funcionario_formateado,
            'loaded_by' => $currentUser['usuario'],
            'user_role' => $currentUser['rol']
        ]);
        
    } else {
        // PASO 9: Verificar si el funcionario existe pero está inactivo
        $stmt = $conn->prepare("SELECT activo FROM funcionario WHERE id = ?");
        $stmt->bind_param("i", $funcionario_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $stmt->close();
        
        if ($result->num_rows > 0) {
            $funcionario_inactivo = $result->fetch_assoc();
            if (!$funcionario_inactivo['activo']) {
                throw new Exception('El funcionario está inactivo');
            }
        }
        
        throw new Exception('Funcionario no encontrado');
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