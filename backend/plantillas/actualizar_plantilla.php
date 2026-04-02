<?php
// actualizar_plantilla.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_actualizar_plantilla.txt');

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
log_debug("🆕 NUEVA REQUEST - PUT /plantillas/actualizar_plantilla");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/actualizar_plantilla.php', 'update_template');
    log_debug("✅ Acceso registrado");

    if (!in_array($_SERVER['REQUEST_METHOD'], ['PUT', 'POST'])) {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    $raw_input = file_get_contents('php://input');
    log_debug("📥 Raw input length: " . strlen($raw_input));

    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        log_debug("❌ ERROR JSON: " . json_last_error_msg());
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    log_debug("✅ JSON decodificado correctamente");

    // ==================================================
    // EXTRACCIÓN Y VALIDACIÓN DE PARÁMETROS
    // ==================================================
    $id = isset($input['id']) ? (int) $input['id'] : null;
    $nombre = $input['nombre'] ?? null;
    $cliente_id = $input['cliente_id'] ?? null;
    $es_general = isset($input['es_general']) ? (int) $input['es_general'] : null;
    $modulo = $input['modulo'] ?? null;
    $contenido_html = $input['contenido_html'] ?? null;

    log_debug("📋 Parámetros recibidos:");
    log_debug("   id: " . ($id ?? 'NULL'));
    log_debug("   nombre: " . ($nombre ?? 'NULL'));
    log_debug("   cliente_id: " . ($cliente_id ?? 'NULL'));
    log_debug("   es_general: " . ($es_general ?? 'NULL'));
    log_debug("   modulo: " . ($modulo ?? 'NULL'));
    log_debug("   contenido_html length: " . strlen($contenido_html ?? ''));

    // VALIDACIONES
    if (!$id) {
        throw new Exception('El parámetro id es requerido');
    }

    log_debug("✅ id válido: $id");

    // ==================================================
    // VERIFICAR QUE LA PLANTILLA EXISTE
    // ==================================================
    log_debug("🔍 Verificando si plantilla existe: $id");

    $stmt_check = $conn->prepare("SELECT id, nombre FROM plantillas WHERE id = ?");
    $stmt_check->bind_param("i", $id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        log_debug("❌ Plantilla no encontrada: $id");
        throw new Exception("Plantilla no encontrada con ID: $id");
    }

    $plantilla_actual = $result_check->fetch_assoc();
    log_debug("✅ Plantilla encontrada: " . $plantilla_actual['nombre']);
    $stmt_check->close();

    // ==================================================
    // CONSTRUIR UPDATE DINÁMICO
    // ==================================================
    $campos_update = [];
    $params = [];
    $types = "";

    if ($nombre !== null) {
        $campos_update[] = "nombre = ?";
        $params[] = $nombre;
        $types .= "s";
        log_debug("   → Actualizará nombre");
    }

    if ($cliente_id !== null) {
        $campos_update[] = "cliente_id = ?";
        $params[] = $cliente_id;
        $types .= "i";
        log_debug("   → Actualizará cliente_id");
    }

    if ($es_general !== null) {
        $campos_update[] = "es_general = ?";
        $params[] = $es_general;
        $types .= "i";
        log_debug("   → Actualizará es_general");

        // Si se marca como general, cliente_id debe ser NULL
        if ($es_general == 1 && !in_array("cliente_id = ?", $campos_update)) {
            $campos_update[] = "cliente_id = NULL";
            log_debug("   → Forzando cliente_id = NULL (es general)");
        }
    }

    if ($contenido_html !== null) {
        $campos_update[] = "contenido_html = ?";
        $params[] = $contenido_html;
        $types .= "s";
        log_debug("   → Actualizará contenido_html");
    }

    if ($modulo !== null) {
        $campos_update[] = "modulo = ?";
        $params[] = $modulo;
        $types .= "s";
        log_debug("   → Actualizará modulo");
    }

    if (empty($campos_update)) {
        log_debug("❌ No hay campos para actualizar");
        throw new Exception('No hay campos para actualizar');
    }

    // Agregar fecha_actualizacion automáticamente
    $campos_update[] = "fecha_actualizacion = NOW()";

    // Agregar ID al final
    $params[] = $id;
    $types .= "i";

    // ==================================================
    // EJECUTAR UPDATE
    // ==================================================
    $sql = "UPDATE plantillas SET " . implode(", ", $campos_update) . " WHERE id = ?";

    log_debug("📝 SQL: $sql");
    log_debug("🔗 Types: $types");

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando statement: " . $conn->error);
        throw new Exception('Error preparando statement: ' . $conn->error);
    }

    $stmt->bind_param($types, ...$params);

    log_debug("▶️ Ejecutando UPDATE...");

    if ($stmt->execute()) {
        log_debug("✅ UPDATE EXITOSO");

        // ==================================================
        // OBTENER PLANTILLA ACTUALIZADA
        // ==================================================
        $stmt_get = $conn->prepare("
            SELECT 
                p.*,
                c.nombre_completo as cliente_nombre
            FROM plantillas p
            LEFT JOIN clientes c ON p.cliente_id = c.id
            WHERE p.id = ?
        ");

        $stmt_get->bind_param("i", $id);
        $stmt_get->execute();
        $result = $stmt_get->get_result();
        $plantilla = $result->fetch_assoc();

        $response_data = [
            'success' => true,
            'message' => 'Plantilla actualizada exitosamente',
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
                'usuario_creador' => (int) $plantilla['usuario_creador']
            ]
        ];

        log_debug("📤 Enviando respuesta exitosa...");
        sendJsonResponse($response_data, 200);

    } else {
        $final_error = !empty($error_msg) ? $error_msg : $stmt->error;
        log_debug("❌ ERROR EXECUTE: " . $final_error);
        throw new Exception('Error ejecutando UPDATE: ' . $final_error);
    }

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
    if (isset($stmt_get)) {
        $stmt_get->close();
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