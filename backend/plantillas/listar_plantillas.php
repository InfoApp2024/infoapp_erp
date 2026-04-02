<?php
// listar_plantillas.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_listar_plantillas.txt');

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
log_debug("🆕 NUEVA REQUEST - GET /plantillas");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/listar_plantillas.php', 'list_templates');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    // ==================================================
    // PARÁMETROS OPCIONALES DE FILTRADO
    // ==================================================
    $cliente_id = isset($_GET['cliente_id']) ? (int) $_GET['cliente_id'] : null;
    $es_general = isset($_GET['es_general']) ? (int) $_GET['es_general'] : null;
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : null;
    $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int) $_GET['offset'] : 0;

    log_debug("📋 Parámetros de consulta:");
    log_debug("   cliente_id: " . ($cliente_id ?? 'NULL'));
    log_debug("   es_general: " . ($es_general ?? 'NULL'));
    log_debug("   modulo: " . ($modulo ?? 'NULL'));
    log_debug("   limit: $limit");
    log_debug("   offset: $offset");

    // ==================================================
    // CONSTRUIR QUERY DINÁMICA
    // ==================================================
    $sql = "
        SELECT 
            p.id,
            p.nombre,
            p.modulo,
            p.cliente_id,
            p.es_general,
            p.contenido_html,
            p.fecha_creacion,
            p.fecha_actualizacion,
            p.usuario_creador,
            c.nombre_completo as cliente_nombre,
            u.NOMBRE_USER as creador_usuario
        FROM plantillas p
        LEFT JOIN clientes c ON p.cliente_id = c.id
        LEFT JOIN usuarios u ON p.usuario_creador = u.id
    ";

    $where_conditions = [];
    $params = [];
    $types = "";

    // Filtro por cliente_id
    if ($cliente_id !== null) {
        $where_conditions[] = "p.cliente_id = ?";
        $params[] = $cliente_id;
        $types .= "i";
    }

    // Filtro por es_general
    if ($es_general !== null) {
        $where_conditions[] = "p.es_general = ?";
        $params[] = $es_general;
        $types .= "i";
    }

    // Filtro por modulo
    if ($modulo !== null) {
        $where_conditions[] = "p.modulo = ?";
        $params[] = $modulo;
        $types .= "s";
    }

    // Agregar WHERE si hay condiciones
    if (!empty($where_conditions)) {
        $sql .= " WHERE " . implode(" AND ", $where_conditions);
    }

    // Ordenar y limitar
    $sql .= " ORDER BY p.fecha_creacion DESC LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    log_debug("🔍 Query construida:");
    log_debug("   SQL: " . preg_replace('/\s+/', ' ', $sql));
    log_debug("   Params: " . json_encode($params));
    log_debug("   Types: $types");

    // ==================================================
    // EJECUTAR QUERY
    // ==================================================
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando statement: " . $conn->error);
        throw new Exception('Error preparando statement: ' . $conn->error);
    }

    // Bind params si existen
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    log_debug("✅ Statement preparado y params bindeados");
    log_debug("▶️ Ejecutando query...");

    $stmt->execute();
    $result = $stmt->get_result();

    log_debug("✅ Query ejecutada");
    log_debug("📊 Filas encontradas: " . $result->num_rows);

    // ==================================================
    // PROCESAR RESULTADOS
    // ==================================================
    $plantillas = [];

    while ($row = $result->fetch_assoc()) {
        $plantillas[] = [
            'id' => (int) $row['id'],
            'nombre' => $row['nombre'],
            'modulo' => $row['modulo'],
            'cliente_id' => $row['cliente_id'] ? (int) $row['cliente_id'] : null,
            'cliente_nombre' => $row['cliente_nombre'],
            'es_general' => (bool) $row['es_general'],
            'contenido_html' => $row['contenido_html'],
            'contenido_html_preview' => mb_substr(strip_tags($row['contenido_html']), 0, 100) . '...',
            'contenido_html_length' => strlen($row['contenido_html']),
            'fecha_creacion' => $row['fecha_creacion'],
            'fecha_actualizacion' => $row['fecha_actualizacion'],
            'usuario_creador' => (int) $row['usuario_creador'],
            'creador_usuario' => $row['creador_usuario']
        ];
    }

    log_debug("✅ Resultados procesados: " . count($plantillas) . " plantillas");

    // ==================================================
    // OBTENER TOTAL DE REGISTROS (sin paginación)
    // ==================================================
    $sql_count = "SELECT COUNT(*) as total FROM plantillas p";

    if (!empty($where_conditions)) {
        $sql_count .= " WHERE " . implode(" AND ", array_slice($where_conditions, 0, count($where_conditions)));
    }

    $stmt_count = $conn->prepare($sql_count);

    if (!empty($params) && count($params) > 2) { // Excluir limit y offset
        $count_params = array_slice($params, 0, -2);
        $count_types = substr($types, 0, -2);
        $stmt_count->bind_param($count_types, ...$count_params);
    }

    $stmt_count->execute();
    $result_count = $stmt_count->get_result();
    $total_row = $result_count->fetch_assoc();
    $total = (int) $total_row['total'];

    log_debug("📊 Total de plantillas en BD: $total");

    // ==================================================
    // RESPUESTA
    // ==================================================
    $response = [
        'success' => true,
        'message' => 'Plantillas obtenidas exitosamente',
        'total' => $total,
        'count' => count($plantillas),
        'limit' => $limit,
        'offset' => $offset,
        'data' => $plantillas
    ];

    log_debug("📤 Enviando respuesta...");
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
    if (isset($stmt)) {
        $stmt->close();
        log_debug("🔒 Statement cerrado");
    }
    if (isset($stmt_count)) {
        $stmt_count->close();
        log_debug("🔒 Statement count cerrado");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}
