<?php
// crear_plantilla.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_crear_plantilla.txt');

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
log_debug("🆕 NUEVA REQUEST - POST /plantillas");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/plantillas/crear_plantilla.php', 'create_template');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
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
    $nombre = $input['nombre'] ?? null;
    $cliente_id = $input['cliente_id'] ?? null;
    $modulo = $input['modulo'] ?? 'servicios';
    $es_general = isset($input['es_general']) ? (int) $input['es_general'] : 0;
    $contenido_html = $input['contenido_html'] ?? null;
    $usuario_id = $currentUser['id'];

    log_debug("📋 Parámetros recibidos:");
    log_debug("   nombre: " . ($nombre ?? 'NULL'));
    log_debug("   cliente_id: " . ($cliente_id ?? 'NULL'));
    log_debug("   modulo: " . ($modulo ?? 'NULL'));
    log_debug("   es_general: " . $es_general);
    log_debug("   contenido_html length: " . strlen($contenido_html ?? ''));
    log_debug("   usuario_id: $usuario_id");

    // VALIDACIONES
    $errores = [];

    if (empty($nombre)) {
        $errores[] = 'nombre es requerido';
    }

    if (empty($contenido_html)) {
        $errores[] = 'contenido_html es requerido';
    }

    // Si NO es general, debe tener cliente_id
    if (!$es_general && empty($cliente_id)) {
        $errores[] = 'cliente_id es requerido cuando no es plantilla general';
    }

    // Si ES general, cliente_id debe ser NULL
    if ($es_general && !empty($cliente_id)) {
        log_debug("⚠️ Es general pero tiene cliente_id, forzando a NULL");
        $cliente_id = null;
    }

    if (!empty($errores)) {
        log_debug("❌ Errores de validación: " . implode(', ', $errores));
        throw new Exception('Errores de validación: ' . implode(', ', $errores));
    }

    log_debug("✅ Validaciones OK");

    // VERIFICAR SI CLIENTE EXISTE (si no es general)
    // ==================================================
    if (!$es_general && $cliente_id) {
        log_debug("🔍 Verificando si cliente existe: $cliente_id");

        $stmt_check = $conn->prepare("SELECT id, nombre_completo as nombre_empresa FROM clientes WHERE id = ?");
        $stmt_check->bind_param("i", $cliente_id);
        $stmt_check->execute();
        $result_check = $stmt_check->get_result();
        $cliente = $result_check->fetch_assoc();

        if (!$cliente) {
            log_debug("❌ Cliente no encontrado: $cliente_id");
            throw new Exception("Cliente no encontrado con ID: $cliente_id");
        }

        log_debug("✅ Cliente encontrado: " . $cliente['nombre_empresa']);
        $stmt_check->close();
    }

    // ==================================================
    // VERIFICAR SI YA EXISTE PLANTILLA PARA ESTE CLIENTE
    // ==================================================
    if (!$es_general && $cliente_id) {
        log_debug("🔍 Verificando plantilla existente para cliente: $cliente_id");

        $stmt_dup = $conn->prepare("SELECT id, nombre FROM plantillas WHERE cliente_id = ?");
        $stmt_dup->bind_param("i", $cliente_id);
        $stmt_dup->execute();
        $result_dup = $stmt_dup->get_result();

        if ($result_dup->num_rows > 0) {
            $plantilla_existente = $result_dup->fetch_assoc();
            log_debug("❌ Ya existe plantilla para este cliente: " . $plantilla_existente['nombre']);
            throw new Exception("Ya existe una plantilla para este cliente. Solo puede haber una plantilla por cliente.");
        }

        log_debug("✅ No hay plantilla duplicada");
        $stmt_dup->close();
    }

    // ==================================================
    // VERIFICAR SI YA EXISTE PLANTILLA GENERAL
    // ==================================================
    if ($es_general) {
        log_debug("🔍 Verificando si ya existe plantilla general");

        $stmt_gen = $conn->prepare("SELECT id, nombre FROM plantillas WHERE es_general = 1");
        $stmt_gen->execute();
        $result_gen = $stmt_gen->get_result();

        if ($result_gen->num_rows > 0) {
            $plantilla_general = $result_gen->fetch_assoc();
            log_debug("⚠️ Ya existe plantilla general: " . $plantilla_general['nombre']);
            log_debug("⚠️ Se puede crear otra, pero solo una estará activa");
            // NO lanzamos error, permitimos múltiples generales
            // El sistema usará la más reciente o la que tenga mayor prioridad
        }

        $stmt_gen->close();
    }

    // ==================================================
    // INSERTAR NUEVA PLANTILLA
    // ==================================================
    log_debug("📝 Preparando INSERT...");
    $sql = "INSERT INTO plantillas (
                nombre, 
                modulo,
                cliente_id, 
                es_general, 
                contenido_html, 
                usuario_creador
            ) VALUES (?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando statement: " . $conn->error);
        throw new Exception('Error preparando statement: ' . $conn->error);
    }

    log_debug("✅ Statement preparado");
    log_debug("🔗 Binding params...");

    // Bind parameters
    $stmt->bind_param(
        "ssiisi",
        $nombre,
        $modulo,
        $cliente_id,
        $es_general,
        $contenido_html,
        $usuario_id
    );

    log_debug("✅ Params bindeados");
    log_debug("▶️ Ejecutando INSERT...");

    if ($stmt->execute()) {
        $plantilla_id = $conn->insert_id;
        log_debug("✅✅✅ INSERT EXITOSO!");
        log_debug("🆔 Plantilla creada con ID: $plantilla_id");

        // ==================================================
        // OBTENER PLANTILLA COMPLETA PARA RESPUESTA
        // ==================================================
        log_debug("🔍 Obteniendo plantilla completa...");

        $stmt_get = $conn->prepare("
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
                c.nombre_completo as cliente_nombre
            FROM plantillas p
            LEFT JOIN clientes c ON p.cliente_id = c.id
            WHERE p.id = ?
        ");

        $stmt_get->bind_param("i", $plantilla_id);
        $stmt_get->execute();
        $result = $stmt_get->get_result();
        $plantilla = $result->fetch_assoc();

        log_debug("✅ Plantilla obtenida");

        $response_data = [
            'success' => true,
            'message' => 'Plantilla creada exitosamente',
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
        sendJsonResponse($response_data, 201);
    } else {
        $final_error = !empty($error_msg) ? $error_msg : $stmt->error;
        log_debug("❌ ERROR EXECUTE: " . $final_error);
        throw new Exception('Error ejecutando INSERT: ' . $final_error);
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
        log_debug("🔒 Statement cerrado");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}
