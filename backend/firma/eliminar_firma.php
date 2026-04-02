<?php
// eliminar_firma.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_eliminar_firma.txt');

function log_debug($msg) {
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("ERROR FATAL: " . $error['message']);
        log_debug("Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function($e) {
    log_debug("EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("NUEVA REQUEST ELIMINAR FIRMA");
log_debug("========================================");
log_debug("IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("auth_middleware cargado");
    
    $currentUser = requireAuth();
    log_debug("Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    
    logAccess($currentUser, '/firma/eliminar_firma.php', 'delete_firma');
    log_debug("Acceso registrado");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido. Use DELETE o POST'), 405);
    }
    
    log_debug("Requiriendo conexión...");
    require '../conexion.php';
    log_debug("conexion.php cargado");

    // Obtener ID de la firma (desde query string o body)
    $firma_id = null;
    
    if ($_SERVER['REQUEST_METHOD'] === 'DELETE') {
        // Desde query string para DELETE
        $firma_id = isset($_GET['id']) ? intval($_GET['id']) : null;
        log_debug("ID obtenido desde query string: " . ($firma_id ?? 'NULL'));
    } else {
        // Desde body para POST
        $raw_input = file_get_contents('php://input');
        log_debug("Raw input length: " . strlen($raw_input));
        
        $input = json_decode($raw_input, true);
        if (!$input || json_last_error() !== JSON_ERROR_NONE) {
            log_debug("ERROR JSON: " . json_last_error_msg());
            throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
        }
        
        $firma_id = isset($input['id']) ? intval($input['id']) : null;
        log_debug("ID obtenido desde body: " . ($firma_id ?? 'NULL'));
    }

    if (!$firma_id) {
        log_debug("ID de firma no proporcionado");
        sendJsonResponse(errorResponse('ID de firma requerido'), 400);
    }

    log_debug("Intentando eliminar firma ID: $firma_id");

    // Verificar que la firma existe antes de eliminar
    $stmt_check = $conn->prepare("SELECT f.id, f.id_servicio, s.o_servicio 
                                   FROM firmas f 
                                   INNER JOIN servicios s ON f.id_servicio = s.id 
                                   WHERE f.id = ?");
    if (!$stmt_check) {
        log_debug("ERROR PREPARE check: " . $conn->error);
        throw new Exception('Error prepare check: ' . $conn->error);
    }
    
    $stmt_check->bind_param("i", $firma_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    $firma = $result_check->fetch_assoc();

    if (!$firma) {
        log_debug("Firma no encontrada con ID: $firma_id");
        sendJsonResponse(errorResponse('Firma no encontrada'), 404);
    }

    log_debug("Firma encontrada:");
    log_debug("   id: " . $firma['id']);
    log_debug("   id_servicio: " . $firma['id_servicio']);
    log_debug("   o_servicio: " . $firma['o_servicio']);

    // Eliminar la firma (hard delete)
    $sql = "DELETE FROM firmas WHERE id = ?";
    
    log_debug("Preparando statement DELETE...");
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        log_debug("ERROR PREPARE delete: " . $conn->error);
        throw new Exception('Error prepare delete: ' . $conn->error);
    }
    
    log_debug("Statement preparado correctamente");
    $stmt->bind_param("i", $firma_id);
    
    log_debug("Ejecutando DELETE...");
    
    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        log_debug("DELETE EXITOSO!");
        log_debug("Filas afectadas: $affected_rows");
        
        if ($affected_rows > 0) {
            $response_data = [
                'success' => true,
                'message' => 'Firma eliminada exitosamente',
                'data' => [
                    'idEliminado' => $firma_id,
                    'idServicio' => (int)$firma['id_servicio'],
                    'oServicio' => (int)$firma['o_servicio']
                ]
            ];
            
            log_debug("Preparando respuesta JSON...");
            log_debug("Respuesta preparada (size: " . strlen(json_encode($response_data)) . " bytes)");
            
            sendJsonResponse($response_data, 200);
            
            log_debug("sendJsonResponse ejecutado");
        } else {
            log_debug("No se eliminó ninguna fila");
            sendJsonResponse(errorResponse('No se pudo eliminar la firma'), 500);
        }
        
    } else {
        log_debug("ERROR EXECUTE delete: " . $stmt->error);
        log_debug("Error number: " . $stmt->errno);
        throw new Exception('Error execute delete: ' . $stmt->error);
    }

} catch (Exception $e) {
    log_debug("EXCEPTION CAPTURADA");
    log_debug("Mensaje: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile());
    log_debug("Línea: " . $e->getLine());
    log_debug("Trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_check)) {
        $stmt_check->close();
        log_debug("Statement check cerrado");
    }
    if (isset($stmt)) {
        $stmt->close();
        log_debug("Statement cerrado");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("REQUEST FINALIZADA");
    log_debug("========================================\n");
}
?>