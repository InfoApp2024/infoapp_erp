<?php
// obtener_plantilla.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_obtener_plantilla.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function () {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("🔴 ERROR FATAL: " . $error['message']);
        log_debug("📁 Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function ($e) {
    log_debug("🔴 EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("📚 Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST - GET /plantillas/obtener_plantilla");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/obtener_plantilla.php', 'get_template');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    // ==================================================
    // VALIDAR PARÁMETRO id
    // ==================================================
    $id = isset($_GET['id']) ? (int) $_GET['id'] : null;

    log_debug("📋 Parámetro recibido:");
    log_debug("   id: " . ($id ?? 'NULL'));

    if (!$id) {
        log_debug("❌ id es requerido");
        throw new Exception('El parámetro id es requerido');
    }

    log_debug("✅ id válido: $id");

    // ==================================================
    // OBTENER PLANTILLA
    // ==================================================
    log_debug("🔍 Buscando plantilla ID: $id");

    $stmt = $conn->prepare("
        SELECT 
            p.*,
            c.nombre_completo as cliente_nombre,
            u.NOMBRE_USER as creador_usuario
        FROM plantillas p
        LEFT JOIN clientes c ON p.cliente_id = c.id
        LEFT JOIN usuarios u ON p.usuario_creador = u.id
        WHERE p.id = ?
    ");

    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        log_debug("❌ Plantilla no encontrada");
        throw new Exception("Plantilla no encontrada con ID: $id");
    }

    $plantilla = $result->fetch_assoc();
    log_debug("✅ Plantilla encontrada: " . $plantilla['nombre']);

    $stmt->close();

    // ==================================================
    // RESPUESTA
    // ==================================================
    $response = [
        'success' => true,
        'message' => 'Plantilla obtenida exitosamente',
        'data' => [
            'id' => (int) $plantilla['id'],
            'nombre' => $plantilla['nombre'],
            'modulo' => $plantilla['modulo'],
            'cliente_id' => $plantilla['cliente_id'] ? (int) $plantilla['cliente_id'] : null,
            'cliente_nombre' => $plantilla['cliente_nombre'],
            'es_general' => (bool) $plantilla['es_general'],
            'contenido_html' => $plantilla['contenido_html'],
            'fecha_creacion' => $plantilla['fecha_creacion'],
            'fecha_actualizacion' => $plantilla['fecha_actualizacion'],
            'usuario_creador' => (int) $plantilla['usuario_creador'],
            'creador_usuario' => $plantilla['creador_usuario']
        ]
    ];

    log_debug("📤 Enviando respuesta exitosa...");
    sendJsonResponse($response, 200);

    log_debug("✅ Respuesta enviada exitosamente");

} catch (Exception $e) {
    log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
    log_debug("❌ Mensaje: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile());
    log_debug("📍 Línea: " . $e->getLine());
    log_debug("📚 Trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt)) {
        $stmt->close();
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