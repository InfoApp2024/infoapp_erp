<?php
// listar_clientes.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_listar_clientes.txt');

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
log_debug("🆕 NUEVA REQUEST - GET /plantillas/listar_clientes");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/listar_clientes.php', 'list_clients');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    // ==================================================
    // PARÁMETROS OPCIONALES
    // ==================================================
    $busqueda = isset($_GET['busqueda']) ? trim($_GET['busqueda']) : null;
    $activos_solo = isset($_GET['activos_solo']) ? (int) $_GET['activos_solo'] : 1;
    $limit = isset($_GET['limit']) ? (int) $_GET['limit'] : 100;
    $offset = isset($_GET['offset']) ? (int) $_GET['offset'] : 0;

    log_debug("📋 Parámetros de consulta:");
    log_debug("   busqueda: " . ($busqueda ?? 'NULL'));
    log_debug("   activos_solo: $activos_solo");
    log_debug("   limit: $limit");
    log_debug("   offset: $offset");

    // ==================================================
    // CONSTRUIR QUERY - AGRUPAR POR CLIENTE
    // ==================================================
    $sql = "
        SELECT 
            c.nombre_completo,
            ci.nombre as ciudad,
            c.id,
            c.documento_nit as codigo,
            c.estado as activo,
            COUNT(DISTINCT p.id) as plantillas_ids,
            GROUP_CONCAT(DISTINCT p.nombre SEPARATOR ' | ') as plantillas_nombres
        FROM clientes c
        LEFT JOIN ciudades ci ON c.ciudad_id = ci.id
        LEFT JOIN plantillas p ON c.id = p.cliente_id
    ";

    $where_conditions = [];
    $params = [];
    $types = "";

    // Filtro de búsqueda
    if ($busqueda !== null && $busqueda !== '') {
        $where_conditions[] = "(c.nombre_completo LIKE ? OR c.documento_nit LIKE ? OR ci.nombre LIKE ?)";
        $busqueda_param = '%' . $busqueda . '%';
        $params[] = $busqueda_param;
        $params[] = $busqueda_param;
        $params[] = $busqueda_param;
        $types .= "sss";
    }

    // Filtro de activos
    if ($activos_solo) {
        $where_conditions[] = "c.estado = 1";
    }

    // Aplicar filtros
    if (!empty($where_conditions)) {
        $sql .= " WHERE " . implode(" AND ", $where_conditions);
    }

    $sql .= " GROUP BY c.id ORDER BY c.nombre_completo ASC";

    // Paginación
    $sql .= " LIMIT ? OFFSET ?";
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    log_debug("🔍 Query construida");
    log_debug("   Params: " . count($params));

    // ==================================================
    // EJECUTAR QUERY
    // ==================================================
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando statement: " . $conn->error);
        throw new Exception('Error preparando statement: ' . $conn->error);
    }

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    log_debug("▶️ Ejecutando query...");
    $stmt->execute();
    $result = $stmt->get_result();

    log_debug("✅ Query ejecutada");
    log_debug("📊 Filas encontradas: " . $result->num_rows);

    // ==================================================
    // PROCESAR RESULTADOS
    // ==================================================
    $clientes = [];

    while ($row = $result->fetch_assoc()) {
        $plantillas = [];

        if (!empty($row['plantillas_ids'])) {
            $ids = explode(',', $row['plantillas_ids']);
            $nombres = explode(' | ', $row['plantillas_nombres']);

            for ($i = 0; $i < count($ids); $i++) {
                $plantillas[] = [
                    'id' => (int) $ids[$i],
                    'nombre' => $nombres[$i] ?? 'Sin nombre'
                ];
            }
        }

        $clientes[] = [
            'id' => (int) $row['id'],
            'nombre_completo' => $row['nombre_completo'],
            'nombre_empresa' => $row['nombre_completo'],
            'ciudad' => $row['ciudad'],
            'documento_nit' => $row['codigo'],
            'codigo' => $row['codigo'],
            'activo' => (bool) $row['activo'],
            'total_servicios' => 0, // No calculado en esta query
            'total_equipos' => 0,   // No calculado en esta query
            'tiene_plantilla' => !empty($plantillas),
            'plantillas' => $plantillas
        ];
    }

    log_debug("✅ Resultados procesados: " . count($clientes) . " clientes");

    // ==================================================
    // OBTENER TOTAL (sin paginación)
    // ==================================================
    $sql_count = "
        SELECT COUNT(DISTINCT CONCAT(c.nombre_completo, '-', IFNULL(ci.nombre, ''))) as total 
        FROM clientes c
        LEFT JOIN ciudades ci ON c.ciudad_id = ci.id
    ";

    if (!empty($where_conditions)) {
        $sql_count .= " WHERE " . implode(" AND ", array_slice($where_conditions, 0, count($where_conditions)));
    }

    $stmt_count = $conn->prepare($sql_count);

    if (!empty($params) && count($params) > 2) {
        $count_params = array_slice($params, 0, -2); // Excluir limit y offset
        $count_types = substr($types, 0, -2);
        if (!empty($count_params)) {
            $stmt_count->bind_param($count_types, ...$count_params);
        }
    }

    $stmt_count->execute();
    $result_count = $stmt_count->get_result();
    $total_row = $result_count->fetch_assoc();
    $total = (int) $total_row['total'];

    log_debug("📊 Total de clientes únicos: $total");

    // ==================================================
    // RESPUESTA
    // ==================================================
    $response = [
        'success' => true,
        'message' => 'Clientes obtenidos exitosamente',
        'total' => $total,
        'count' => count($clientes),
        'limit' => $limit,
        'offset' => $offset,
        'data' => $clientes
    ];

    log_debug("📤 Enviando respuesta...");
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
    if (isset($stmt_count)) {
        $stmt_count->close();
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}
