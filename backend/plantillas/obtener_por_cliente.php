<?php
// obtener_por_cliente.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_obtener_por_cliente.txt');

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
log_debug("🆕 NUEVA REQUEST - GET /plantillas/obtener_por_cliente");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/obtener_por_cliente.php', 'get_template_by_client');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    // ==================================================
    // VALIDAR PARÁMETRO cliente_id
    // ==================================================
    $cliente_id = isset($_GET['cliente_id']) ? (int) $_GET['cliente_id'] : null;
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'servicios';

    log_debug("📋 Parámetros recibidos:");
    log_debug("   cliente_id: " . ($cliente_id ?? 'NULL'));
    log_debug("   modulo: " . ($modulo ?? 'NULL'));

    if (!$cliente_id) {
        log_debug("❌ cliente_id es requerido");
        throw new Exception('El parámetro cliente_id es requerido');
    }

    log_debug("✅ cliente_id válido: $cliente_id");

    // ==================================================
    // VERIFICAR QUE EL CLIENTE EXISTE
    // ==================================================
    log_debug("🔍 Verificando si cliente existe: $cliente_id");

    $stmt_cliente = $conn->prepare("SELECT id, nombre_completo as nombre_empresa FROM clientes WHERE id = ?");
    $stmt_cliente->bind_param("i", $cliente_id);
    $stmt_cliente->execute();
    $result_cliente = $stmt_cliente->get_result();
    $cliente = $result_cliente->fetch_assoc();

    if (!$cliente) {
        log_debug("❌ Cliente no encontrado: $cliente_id");
        throw new Exception("Cliente no encontrado con ID: $cliente_id");
    }

    log_debug("✅ Cliente encontrado: " . $cliente['nombre_empresa']);
    $stmt_cliente->close();

    // ==================================================
    // ESTRATEGIA DE BÚSQUEDA DE PLANTILLA
    // ==================================================
    log_debug("🔍 Iniciando búsqueda de plantilla...");

    $plantilla = null;
    $tipo_plantilla = null;

    // PASO 1: Buscar plantilla específica del cliente
    log_debug("📋 PASO 1: Buscando plantilla específica para cliente $cliente_id...");

    $stmt_especifica = $conn->prepare("
        SELECT 
            p.id,
            p.nombre,
            p.cliente_id,
            p.es_general,
            p.contenido_html,
            p.fecha_creacion,
            p.fecha_actualizacion,
            p.usuario_creador,
            c.nombre_completo as cliente_nombre
        FROM plantillas p
        LEFT JOIN clientes c ON p.cliente_id = c.id
        WHERE p.cliente_id = ? AND p.modulo = ?
        LIMIT 1
    ");

    $stmt_especifica->bind_param("is", $cliente_id, $modulo);
    $stmt_especifica->execute();
    $result_especifica = $stmt_especifica->get_result();

    if ($result_especifica->num_rows > 0) {
        $plantilla = $result_especifica->fetch_assoc();
        $tipo_plantilla = 'especifica';
        log_debug("✅ Plantilla específica encontrada: " . $plantilla['nombre'] . " (ID: " . $plantilla['id'] . ")");
    } else {
        log_debug("⚠️ No se encontró plantilla específica para este cliente");
    }

    $stmt_especifica->close();

    // PASO 2: Si no hay plantilla específica, buscar plantilla general
    if (!$plantilla) {
        log_debug("📋 PASO 2: Buscando plantilla general...");

        $stmt_general = $conn->prepare("
            SELECT 
                p.id,
                p.nombre,
                p.cliente_id,
                p.es_general,
                p.contenido_html,
                p.fecha_creacion,
                p.fecha_actualizacion,
                p.usuario_creador,
                NULL as cliente_nombre
            FROM plantillas p
            WHERE p.es_general = 1 AND p.modulo = ?
            ORDER BY p.fecha_creacion DESC
            LIMIT 1
        ");

        $stmt_general->bind_param("s", $modulo);
        $stmt_general->execute();
        $result_general = $stmt_general->get_result();

        if ($result_general->num_rows > 0) {
            $plantilla = $result_general->fetch_assoc();
            $tipo_plantilla = 'general';
            log_debug("✅ Plantilla general encontrada: " . $plantilla['nombre'] . " (ID: " . $plantilla['id'] . ")");
        } else {
            log_debug("⚠️ No se encontró plantilla general");
        }

        $stmt_general->close();
    }

    // PASO 3: Si no hay ninguna plantilla, devolver error informativo
    if (!$plantilla) {
        log_debug("❌ No hay plantillas disponibles");

        $response = [
            'success' => false,
            'message' => 'No hay plantillas disponibles',
            'data' => [
                'cliente_id' => $cliente_id,
                'cliente_nombre' => $cliente['nombre_empresa'],
                'plantilla_encontrada' => false,
                'tipo_plantilla' => null,
                'sugerencia' => 'Debe crear al menos una plantilla general o una plantilla específica para este cliente.'
            ]
        ];

        log_debug("📤 Enviando respuesta: No hay plantillas");
        sendJsonResponse($response, 404);
        exit;
    }

    // ==================================================
    // RESPUESTA EXITOSA
    // ==================================================
    log_debug("✅ Plantilla seleccionada exitosamente");
    log_debug("   Tipo: $tipo_plantilla");
    log_debug("   ID: " . $plantilla['id']);
    log_debug("   Nombre: " . $plantilla['nombre']);

    $response = [
        'success' => true,
        'message' => 'Plantilla obtenida exitosamente',
        'data' => [
            'plantilla' => [
                'id' => (int) $plantilla['id'],
                'nombre' => $plantilla['nombre'],
                'modulo' => $plantilla['modulo'] ?? $modulo,
                'cliente_id' => $plantilla['cliente_id'] ? (int) $plantilla['cliente_id'] : null,
                'cliente_nombre' => $plantilla['cliente_nombre'],
                'es_general' => (bool) $plantilla['es_general'],
                'contenido_html' => $plantilla['contenido_html'],
                'fecha_creacion' => $plantilla['fecha_creacion'],
                'fecha_actualizacion' => $plantilla['fecha_actualizacion'],
                'usuario_creador' => (int) $plantilla['usuario_creador']
            ],
            'tipo_plantilla' => $tipo_plantilla,
            'cliente_solicitado' => [
                'id' => $cliente_id,
                'nombre' => $cliente['nombre_empresa']
            ],
            'info' => $tipo_plantilla === 'especifica'
                ? 'Usando plantilla específica para este cliente'
                : 'Usando plantilla general (el cliente no tiene plantilla específica)'
        ]
    ];

    log_debug("📤 Enviando respuesta exitosa...");
    log_debug("📊 Tamaño respuesta: " . strlen(json_encode($response)) . " bytes");

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
    if (isset($stmt_cliente)) {
        $stmt_cliente->close();
    }
    if (isset($stmt_especifica)) {
        $stmt_especifica->close();
    }
    if (isset($stmt_general)) {
        $stmt_general->close();
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