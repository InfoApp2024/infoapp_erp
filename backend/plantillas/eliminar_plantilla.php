<?php
// eliminar_plantilla.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_eliminar_plantilla.txt');

function log_debug($msg) {
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("🔴 ERROR FATAL: " . $error['message']);
        log_debug("📁 Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function($e) {
    log_debug("🔴 EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("📚 Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST - DELETE /plantillas/eliminar_plantilla");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");
    
    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    
    logAccess($currentUser, '/plantillas/eliminar_plantilla.php', 'delete_template');
    log_debug("✅ Acceso registrado");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    // ==================================================
    // VALIDAR PARÁMETRO id
    // ==================================================
    $id = isset($_GET['id']) ? (int)$_GET['id'] : null;

    log_debug("📋 Parámetro recibido:");
    log_debug("   id: " . ($id ?? 'NULL'));

    if (!$id) {
        log_debug("❌ id es requerido");
        throw new Exception('El parámetro id es requerido');
    }

    log_debug("✅ id válido: $id");

    // ==================================================
    // VERIFICAR QUE LA PLANTILLA EXISTE
    // ==================================================
    log_debug("🔍 Verificando si plantilla existe: $id");
    
    $stmt_check = $conn->prepare("
        SELECT 
            p.id, 
            p.nombre, 
            p.cliente_id,
            p.es_general,
            c.nombre_completo as cliente_nombre
        FROM plantillas p
        LEFT JOIN clientes c ON p.cliente_id = c.id
        WHERE p.id = ?
    ");
    $stmt_check->bind_param("i", $id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    
    if ($result_check->num_rows === 0) {
        log_debug("❌ Plantilla no encontrada: $id");
        throw new Exception("Plantilla no encontrada con ID: $id");
    }
    
    $plantilla = $result_check->fetch_assoc();
    log_debug("✅ Plantilla encontrada: " . $plantilla['nombre']);
    log_debug("   Cliente: " . ($plantilla['cliente_nombre'] ?? 'General'));
    log_debug("   Es general: " . ($plantilla['es_general'] ? 'Sí' : 'No'));
    
    $stmt_check->close();

    // ==================================================
    // ADVERTENCIA SI ES PLANTILLA GENERAL
    // ==================================================
    if ($plantilla['es_general']) {
        log_debug("⚠️ ADVERTENCIA: Se está eliminando la plantilla general");
    }

    // ==================================================
    // ELIMINAR PLANTILLA
    // ==================================================
    log_debug("🗑️ Eliminando plantilla ID: $id");
    
    $stmt_delete = $conn->prepare("DELETE FROM plantillas WHERE id = ?");
    $stmt_delete->bind_param("i", $id);
    
    if ($stmt_delete->execute()) {
        $affected_rows = $stmt_delete->affected_rows;
        log_debug("✅ DELETE EXITOSO. Filas afectadas: $affected_rows");
        
        if ($affected_rows === 0) {
            log_debug("⚠️ No se eliminó ninguna fila");
            throw new Exception("No se pudo eliminar la plantilla");
        }
        
        $response = [
            'success' => true,
            'message' => 'Plantilla eliminada exitosamente',
            'data' => [
                'id' => $id,
                'nombre' => $plantilla['nombre'],
                'cliente_nombre' => $plantilla['cliente_nombre'],
                'era_general' => (bool)$plantilla['es_general']
            ]
        ];
        
        log_debug("📤 Enviando respuesta exitosa...");
        sendJsonResponse($response, 200);
        
    } else {
        log_debug("❌ ERROR DELETE: " . $stmt_delete->error);
        throw new Exception('Error ejecutando DELETE: ' . $stmt_delete->error);
    }

} catch (Exception $e) {
    log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
    log_debug("❌ Mensaje: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile());
    log_debug("📍 Línea: " . $e->getLine());
    log_debug("📚 Trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_check)) {
        $stmt_check->close();
    }
    if (isset($stmt_delete)) {
        $stmt_delete->close();
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}
?>