<?php
/**
 * POST /API_Infoapp/servicio/centros_costo/actualizar.php
 * 
 * Endpoint para actualizar el nombre de un centro de costo existente
 * Requiere autenticación JWT
 */

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio/centros_costo/actualizar.php', 'update_centro_costo');
    
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
    
    if (!$data || !isset($data['nombre_anterior']) || !isset($data['nombre_nuevo'])) {
        sendJsonResponse(errorResponse('Se requieren nombre_anterior y nombre_nuevo'), 400);
    }
    
    $nombreAnterior = trim($data['nombre_anterior']);
    $nombreNuevo = trim($data['nombre_nuevo']);
    
    if (strlen($nombreNuevo) < 3) {
        sendJsonResponse(errorResponse('El nombre debe tener al menos 3 caracteres'), 400);
    }
    
    if (strtolower($nombreAnterior) === strtolower($nombreNuevo)) {
        sendJsonResponse(errorResponse('El nombre nuevo debe ser diferente al anterior'), 400);
    }
    
    // Verificar si el nombre nuevo ya existe
    $check_stmt = $conn->prepare(
        "SELECT id FROM centros_costo WHERE LOWER(nombre) = LOWER(?) AND LOWER(nombre) != LOWER(?)"
    );
    $check_stmt->bind_param('ss', $nombreNuevo, $nombreAnterior);
    $check_stmt->execute();
    
    if ($check_stmt->get_result()->num_rows > 0) {
        sendJsonResponse(errorResponse('Ya existe un centro de costo con ese nombre'), 400);
    }
    
    // Iniciar transacción
    $conn->begin_transaction();
    
    try {
        // Actualizar en tabla centros_costo
        $stmt1 = $conn->prepare(
            "UPDATE centros_costo SET nombre = ?, updated_at = CURRENT_TIMESTAMP WHERE LOWER(nombre) = LOWER(?)"
        );
        $stmt1->bind_param('ss', $nombreNuevo, $nombreAnterior);
        
        if (!$stmt1->execute()) {
            throw new Exception("Error actualizando centro de costo: " . $stmt1->error);
        }
        
        if ($stmt1->affected_rows === 0) {
            throw new Exception("Centro de costo no encontrado");
        }
        
        // Actualizar en tabla servicios
        $stmt2 = $conn->prepare(
            "UPDATE servicios SET centro_costo = ? WHERE LOWER(centro_costo) = LOWER(?)"
        );
        $stmt2->bind_param('ss', $nombreNuevo, $nombreAnterior);
        $stmt2->execute();
        
        $serviciosActualizados = $stmt2->affected_rows;
        
        // Commit
        $conn->commit();
        
        sendJsonResponse([
            'success' => true,
            'message' => 'Centro de costo actualizado exitosamente',
            'servicios_actualizados' => $serviciosActualizados,
            'updated_by' => $currentUser['usuario'],
            'user_role' => $currentUser['rol']
        ]);
        
    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>