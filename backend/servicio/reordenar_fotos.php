<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/reordenar_fotos.php', 'reorder_photos');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Leer input
    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);
    
    if (!$input || !isset($input['ordenes']) || !is_array($input['ordenes'])) {
        throw new Exception('Datos invélidos. Se requiere array "ordenes"');
    }

    // PASO 5.5: Verificar si el servicio estÃ¡ en un estado final protegido
    // Obtenemos el servicio_id de la primera foto del array para validar
    if (count($input['ordenes']) > 0) {
        $first_foto_id = (int)$input['ordenes'][0]['id'];

        // Primero, obtener el servicio_id de la foto
        $stmt_get_servicio_id = $conn->prepare("SELECT servicio_id FROM fotos_servicio WHERE id = ?");
        $stmt_get_servicio_id->bind_param("i", $first_foto_id);
        $stmt_get_servicio_id->execute();
        $res_get_servicio_id = $stmt_get_servicio_id->get_result();
        if (!$row_get_servicio_id = $res_get_servicio_id->fetch_assoc()) {
            throw new Exception("Foto no encontrada.");
        }
        $servicio_id = $row_get_servicio_id['servicio_id'];
        $stmt_get_servicio_id->close();

        // Luego, verificar el estado del servicio
        $stmt_check = $conn->prepare("
            SELECT e.estado_base_codigo 
            FROM servicios s
            INNER JOIN estados_proceso e ON s.estado = e.id
            WHERE s.id = ?
        ");
        $stmt_check->bind_param("i", $servicio_id); // Usar servicio_id aquí
        $stmt_check->execute();
        $res_check = $stmt_check->get_result();
        
        if ($row_check = $res_check->fetch_assoc()) {
            $estado_base = $row_check['estado_base_codigo'];
            if (in_array($estado_base, ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'])) {
                throw new Exception("No se pueden reordenar fotos de un servicio en estado final ($estado_base).");
            }
        }
        $stmt_check->close();
    }

    // PASO 6: Actualizar orden en transacción
    $conn->begin_transaction();
    
    $stmt = $conn->prepare("UPDATE fotos_servicio SET orden_visualizacion = ? WHERE id = ?");
    
    $updated_count = 0;
    foreach ($input['ordenes'] as $item) {
        if (!isset($item['id']) || !isset($item['orden'])) {
            continue;
        }
        
        $id = (int)$item['id'];
        $orden = (int)$item['orden'];
        
        $stmt->bind_param("ii", $orden, $id);
        if ($stmt->execute()) {
            $updated_count++;
        }
    }
    
    $conn->commit();
    
    // PASO 7: Respuesta exitosa
    sendJsonResponse([
        'success' => true, 
        'message' => "Orden actualizado correctamente ($updated_count fotos)",
    ]);

} catch (Exception $e) {
    if (isset($conn)) {
        $conn->rollback();
    }
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
?>
