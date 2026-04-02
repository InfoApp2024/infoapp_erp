<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Log de acceso
    logAccess($currentUser, '/eliminar_foto_servicio.php', 'delete_photo');
    
    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 4: Conexión a BD
    require '../conexion.php';
    
    // PASO 5: Leer y validar input
    $raw_input = file_get_contents('php://input');
    error_log("=== DEBUG ELIMINAR FOTO (JWT) ===");
    error_log("Usuario autenticado: " . $currentUser['usuario']);
    error_log("Raw input: " . $raw_input);
    
    $input = json_decode($raw_input, true);
    error_log("Input decodificado: " . print_r($input, true));
    
    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }
    
    $foto_id = $input['foto_id'] ?? null;
    error_log("foto_id recibido: " . $foto_id . " (tipo: " . gettype($foto_id) . ")");
    
    if (!$foto_id || $foto_id <= 0) {
        throw new Exception('foto_id es requerido y debe ser mayor a 0. Recibido: ' . $foto_id);
    }
    
    // PASO 6: Verificar que la foto existe
    $stmt = $conn->prepare("SELECT id, ruta_archivo, nombre_archivo, servicio_id FROM fotos_servicio WHERE id = ?");
    $stmt->bind_param("i", $foto_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $foto = $result->fetch_assoc();
    
    error_log("Foto encontrada: " . print_r($foto, true));
    
    if (!$foto) {
        // Debug: Mostrar fotos disponibles
        $stmt_debug = $conn->prepare("SELECT id, nombre_archivo FROM fotos_servicio ORDER BY id");
        $stmt_debug->execute();
        $result_debug = $stmt_debug->get_result();
        $fotos_disponibles = [];
        while ($row_debug = $result_debug->fetch_assoc()) {
            $fotos_disponibles[] = $row_debug;
        }
        error_log("Fotos disponibles en BD: " . print_r($fotos_disponibles, true));
        
        throw new Exception('Foto no encontrada con ID: ' . $foto_id);
    }
    
    // PASO 6.5: Verificar si el servicio está en un estado final protegido
    $servicio_id_foto = $foto['servicio_id'];
    $stmt_check = $conn->prepare("
        SELECT e.estado_base_codigo 
        FROM servicios s
        INNER JOIN estados_proceso e ON s.estado = e.id
        WHERE s.id = ?
    ");
    $stmt_check->bind_param("i", $servicio_id_foto);
    $stmt_check->execute();
    $res_check = $stmt_check->get_result();
    
    if ($row_check = $res_check->fetch_assoc()) {
        $estado_base = $row_check['estado_base_codigo'];
        if (in_array($estado_base, ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'])) {
            throw new Exception("No se puede eliminar una foto de un servicio en estado final ($estado_base).");
        }
    }
    $stmt_check->close();
    
    // PASO 7: Eliminar archivo físico si existe
    if (file_exists($foto['ruta_archivo'])) {
        $eliminado = unlink($foto['ruta_archivo']);
        error_log("Archivo físico eliminado: " . ($eliminado ? 'SÍ' : 'NO') . " - Ruta: " . $foto['ruta_archivo']);
    } else {
        error_log("Archivo físico no existe: " . $foto['ruta_archivo']);
    }
    
    // PASO 8: Eliminar registro de la base de datos
    $stmt = $conn->prepare("DELETE FROM fotos_servicio WHERE id = ?");
    $stmt->bind_param("i", $foto_id);
    
    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        error_log("Filas afectadas: " . $affected_rows);
        
        if ($affected_rows > 0) {
            // PASO 9: Respuesta exitosa con contexto de usuario
            sendJsonResponse([
                'success' => true,
                'message' => 'Foto eliminada exitosamente',
                'data' => [
                    'foto_id' => intval($foto_id),
                    'servicio_id' => intval($foto['servicio_id']),
                    'archivo_eliminado' => $foto['nombre_archivo'],
                    'eliminado_by_user' => $currentUser['usuario'],
                    'eliminado_by_role' => $currentUser['rol']
                ]
            ]);
        } else {
            throw new Exception('No se eliminó ninguna fila. La foto con ID ' . $foto_id . ' podría no existir.');
        }
    } else {
        throw new Exception('Error ejecutando DELETE: ' . $stmt->error);
    }
    
} catch (Exception $e) {
    error_log("❌ ERROR: " . $e->getMessage());
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