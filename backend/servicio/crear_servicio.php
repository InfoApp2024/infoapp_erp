<?php
// crear_servicio.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// define('DEBUG_LOG', __DIR__ . '/debug_crear_servicio.txt');
define('DEBUG_LOG', false); // Desactivar logs en producción para rendimiento

function log_debug($msg)
{
    if (!DEBUG_LOG)
        return;
    $time = date('Y-m-d H:i:s');
    // $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    // file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
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
log_debug("🆕 NUEVA REQUEST INICIADA");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

// $start_time = microtime(true);
// $timers = ['start' => 0];

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/crear_servicio.php', 'create_service');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión y WebSocket...");
    require '../conexion.php';
    // $timers['db_connect'] = microtime(true) - $start_time;
    log_debug("✅ conexion.php cargado");
    require 'WebSocketNotifier.php';
    log_debug("✅ WebSocketNotifier.php cargado");
    require_once 'helpers/trazabilidad_helper.php';
    log_debug("✅ trazabilidad_helper.php cargado");

    $raw_input = file_get_contents('php://input');
    log_debug("📥 Raw input length: " . strlen($raw_input));
    log_debug("📥 Raw input: " . $raw_input);

    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        log_debug("❌ ERROR JSON: " . json_last_error_msg());
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    log_debug("✅ JSON decodificado correctamente");

    $fecha_ingreso = $input['fecha_ingreso'] ?? null;
    $orden_cliente = $input['orden_cliente'] ?? null;
    $autorizado_por = $input['autorizado_por'] ?? null;
    $tipo_mantenimiento = $input['tipo_mantenimiento'] ?? null;
    $centro_costo = $input['centro_costo'] ?? '';
    $id_equipo = $input['id_equipo'] ?? null;
    $estado_id = $input['estado_id'] ?? null;
    $cliente_id = $input['cliente_id'] ?? null; // ✅ NUEVO
    $o_servicio = isset($input['o_servicio']) ? intval($input['o_servicio']) : null;
    $es_primer_servicio = isset($input['es_primer_servicio']) ? $input['es_primer_servicio'] : false;
    $actividad_id = isset($input['actividad_id']) ? intval($input['actividad_id']) : null;
    $usuario_id = $currentUser['id'];

    log_debug("📋 Variables extraídas:");
    log_debug("   fecha_ingreso: " . ($fecha_ingreso ?? 'NULL'));
    log_debug("   orden_cliente: " . ($orden_cliente ?? 'NULL'));
    log_debug("   cliente_id: " . ($cliente_id ?? 'NULL')); // ✅ NUEVO
    log_debug("   autorizado_por: " . ($autorizado_por ?? 'NULL'));
    log_debug("   tipo_mantenimiento RAW: '" . ($tipo_mantenimiento ?? 'NULL') . "'");
    log_debug("   tipo_mantenimiento tipo: " . gettype($tipo_mantenimiento));
    log_debug("   centro_costo: " . ($centro_costo === '' ? 'EMPTY' : $centro_costo));
    log_debug("   id_equipo: " . ($id_equipo ?? 'NULL'));
    log_debug("   estado_id: " . ($estado_id ?? 'NULL'));
    log_debug("   actividad_id: " . ($actividad_id ?? 'NULL'));
    log_debug("   usuario_id: $usuario_id");

    $errores = [];
    // ✅ VALIDACIÓN ROBUSTA DE CAMPOS MANDATORIOS (App y API/Postman)
    if (empty($fecha_ingreso))
        $errores[] = 'fecha_ingreso';
    if (empty(trim((string) $orden_cliente)))
        $errores[] = 'orden_cliente';
    if (!$cliente_id || intval($cliente_id) <= 0)
        $errores[] = 'cliente_id';
    if (!$autorizado_por || intval($autorizado_por) <= 0)
        $errores[] = 'autorizado_por';
    if (empty(trim((string) $tipo_mantenimiento)))
        $errores[] = 'tipo_mantenimiento';
    if (empty(trim((string) $centro_costo)))
        $errores[] = 'centro_costo';
    if (!$id_equipo || intval($id_equipo) <= 0)
        $errores[] = 'id_equipo';
    if (!$estado_id || intval($estado_id) <= 0)
        $errores[] = 'estado_id';
    if (!$actividad_id || intval($actividad_id) <= 0)
        $errores[] = 'actividad_id';

    if (!empty($errores)) {
        log_debug("❌ Faltan campos: " . implode(', ', $errores));
        throw new Exception('Campos faltantes: ' . implode(', ', $errores));
    }

    log_debug("✅ Validación de campos requeridos OK");

    // NORMALIZACIÓN DEL TIPO DE MANTENIMIENTO
    log_debug("🔍 ANTES de normalizar tipo_mantenimiento:");
    log_debug("   Valor: '" . $tipo_mantenimiento . "'");
    log_debug("   Tipo: " . gettype($tipo_mantenimiento));
    log_debug("   Longitud: " . strlen($tipo_mantenimiento));

    $tipo_mantenimiento = trim($tipo_mantenimiento);
    log_debug("🔍 DESPUÉS de trim():");
    log_debug("   Valor: '" . $tipo_mantenimiento . "'");
    log_debug("   Longitud: " . strlen($tipo_mantenimiento));

    if (empty($tipo_mantenimiento)) {
        log_debug("❌ tipo_mantenimiento está vacío después de trim");
        throw new Exception('Tipo de mantenimiento requerido');
    }

    $tipo_mantenimiento = strtolower($tipo_mantenimiento);
    log_debug("🔍 DESPUÉS de strtolower():");
    log_debug("   Valor: '" . $tipo_mantenimiento . "'");
    log_debug("   Longitud: " . strlen($tipo_mantenimiento));

    if (strlen($tipo_mantenimiento) < 3) {
        log_debug("❌ tipo_mantenimiento muy corto: longitud = " . strlen($tipo_mantenimiento));
        throw new Exception('Tipo mantenimiento muy corto (mínimo 3 caracteres)');
    }

    log_debug("✅ tipo_mantenimiento normalizado correctamente: '$tipo_mantenimiento'");

    if ($centro_costo === null)
        $centro_costo = '';

    // CONVERSIÓN DE TIPOS (sin tocar tipo_mantenimiento)
    log_debug("🔢 Convirtiendo tipos numéricos...");
    $o_servicio = (int) $o_servicio;
    $autorizado_por = (int) $autorizado_por;
    $id_equipo = (int) $id_equipo;
    $estado_id = (int) $estado_id;
    $actividad_id = (int) $actividad_id;
    $cliente_id = (int) $cliente_id; // ✅ NUEVO
    $orden_cliente = (string) $orden_cliente;
    $usuario_id = (int) $usuario_id;

    log_debug("🔢 Tipos forzados:");
    log_debug("   o_servicio: $o_servicio (" . gettype($o_servicio) . ")");
    log_debug("   autorizado_por: $autorizado_por (" . gettype($autorizado_por) . ")");
    log_debug("   tipo_mantenimiento: '$tipo_mantenimiento' (" . gettype($tipo_mantenimiento) . ")");
    log_debug("   id_equipo: $id_equipo (" . gettype($id_equipo) . ")");
    log_debug("   estado_id: $estado_id (" . gettype($estado_id) . ")");
    log_debug("   actividad_id: $actividad_id (" . gettype($actividad_id) . ")");

    if (!$es_primer_servicio || $o_servicio === 0) {
        log_debug("🔢 Calculando número de servicio automático...");
        $stmt = $conn->prepare("SELECT MAX(o_servicio) as ultimo_numero FROM servicios");
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $ultimo_numero = intval($row['ultimo_numero'] ?? 0);
        $o_servicio = $ultimo_numero + 1;
        log_debug("✅ Número calculado: $o_servicio (anterior: $ultimo_numero)");
    } else {
        log_debug("📌 Usando número proporcionado: $o_servicio");
    }

    log_debug("🔍 Buscando equipo ID: $id_equipo");
    $stmt = $conn->prepare("SELECT nombre_empresa, placa FROM equipos WHERE id = ?");
    if (!$stmt) {
        log_debug("❌ Error preparando query equipo: " . $conn->error);
        throw new Exception('Error preparando query equipo');
    }
    $stmt->bind_param("i", $id_equipo);
    $stmt->execute();
    $result = $stmt->get_result();
    $equipo = $result->fetch_assoc();

    if (!$equipo) {
        log_debug("❌ Equipo no encontrado con ID: $id_equipo");
        throw new Exception('Equipo no encontrado: ' . $id_equipo);
    }
    log_debug("✅ Equipo encontrado:");
    log_debug("   nombre_empresa: " . $equipo['nombre_empresa']);
    log_debug("   placa: " . $equipo['placa']);

    log_debug("🔍 Validando funcionario ID: $autorizado_por");
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM funcionario WHERE id = ?");
    if (!$stmt) {
        log_debug("❌ Error preparando query funcionario: " . $conn->error);
        throw new Exception('Error preparando query funcionario');
    }
    $stmt->bind_param("i", $autorizado_por);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if ($row['count'] == 0) {
        log_debug("❌ Funcionario no existe con ID: $autorizado_por");
        throw new Exception('Funcionario no existe: ' . $autorizado_por);
    }
    log_debug("✅ Funcionario validado");

    $fecha_ingreso_formatted = date('Y-m-d H:i:s', strtotime($fecha_ingreso));
    log_debug("📅 Fecha formateada: $fecha_ingreso_formatted");

    $sql = "INSERT INTO servicios (
                o_servicio, fecha_registro, fecha_ingreso, orden_cliente, 
                cliente_id, autorizado_por, tipo_mantenimiento, centro_costo, 
                id_equipo, nombre_emp, placa, estado, actividad_id, 
                suministraron_repuestos, fotos_confirmadas, firma_confirmada,
                personal_confirmado, anular_servicio, es_finalizado,
                usuario_creador, usuario_ultima_actualizacion, responsable_id
            ) VALUES (
                ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, 0, 0, 0, ?, ?, ?
            )";

    log_debug("📝 SQL preparado (longitud: " . strlen($sql) . " chars)");
    log_debug("🔧 Preparando statement...");

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        log_debug("❌ ERROR PREPARE: " . $conn->error);
        throw new Exception('Error prepare: ' . $conn->error);
    }
    log_debug("✅ Statement preparado correctamente");

    log_debug("🔗 Binding params con tipo: ississsissiiii (14 params)");
    log_debug("   Parámetros a bindear:");
    log_debug("   1. o_servicio (i): $o_servicio");
    log_debug("   2. fecha_ingreso (s): $fecha_ingreso_formatted");
    log_debug("   3. orden_cliente (s): $orden_cliente");
    log_debug("   4. cliente_id (i): $cliente_id");
    log_debug("   5. autorizado_por (i): $autorizado_por");
    log_debug("   6. tipo_mantenimiento (s): '$tipo_mantenimiento' [CRÍTICO]");
    log_debug("   7. centro_costo (s): $centro_costo");
    log_debug("   8. id_equipo (i): $id_equipo");
    log_debug("   9. nombre_empresa (s): " . $equipo['nombre_empresa']);
    log_debug("  10. placa (s): " . $equipo['placa']);
    log_debug("  11. estado_id (i): $estado_id");
    log_debug("  12. actividad_id (i): $actividad_id");
    log_debug("  13. usuario_creador (i): $usuario_id");
    log_debug("  14. usuario_ultima_act (i): $usuario_id");

    $bind_result = @$stmt->bind_param(
        "ississsissiiiii",
        $o_servicio,
        $fecha_ingreso_formatted,
        $orden_cliente,
        $cliente_id,
        $autorizado_por,
        $tipo_mantenimiento,
        $centro_costo,
        $id_equipo,
        $equipo['nombre_empresa'],
        $equipo['placa'],
        $estado_id,
        $actividad_id,
        $usuario_id,
        $usuario_id,
        $usuario_id
    );

    log_debug("🔗 bind_param resultado: " . ($bind_result ? 'TRUE' : 'FALSE'));

    if (!$bind_result) {
        log_debug("❌ ERROR BIND: " . $stmt->error);
        throw new Exception('Error bind: ' . $stmt->error);
    }

    log_debug("✅ Bind exitoso");
    log_debug("▶️ Ejecutando INSERT...");

    if ($stmt->execute()) {
        $servicio_id = $conn->insert_id;
        log_debug("✅✅✅ INSERT EXITOSO!");
        log_debug("🆔 Servicio creado con ID: $servicio_id");
        log_debug("🔢 Número de servicio: $o_servicio");

        // 🏗️ MODO UNIFICADO: Inyectar Operación Maestra
        log_debug("🏗️ Creando Operación Maestra para el servicio...");
        $desc_maestra = (isset($input['desc_maestra']) && !empty($input['desc_maestra']))
            ? trim($input['desc_maestra'])
            : "Alistamiento/General (Maestra)";
        $sql_maestra = "INSERT INTO operaciones (servicio_id, actividad_estandar_id, descripcion, fecha_inicio, is_master, observaciones) 
                        VALUES (?, ?, ?, NOW(), 1, 'Generada automáticamente al crear el servicio')";
        $stmt_maestra = $conn->prepare($sql_maestra);
        if ($stmt_maestra) {
            $stmt_maestra->bind_param("iis", $servicio_id, $actividad_id, $desc_maestra);
            if ($stmt_maestra->execute()) {
                $operacion_maestra_id = $conn->insert_id;
                log_debug("✅ Operación Maestra creada con ID: " . $operacion_maestra_id);

                // ✅ AUTO-ASIGNACIÓN: Agregar al creador como personal inicial de la operación maestra
                // NOTA: El creador es un usuario (tabla usuarios), no staff (tabla staff), usamos usuario_id
                log_debug("👷 Asignando automáticamente al creador como personal inicial...");
                $sql_staff = "INSERT INTO servicio_staff (servicio_id, operacion_id, staff_id, usuario_id, asignado_por) VALUES (?, ?, NULL, ?, ?)";
                $stmt_staff = $conn->prepare($sql_staff);
                if ($stmt_staff) {
                    $stmt_staff->bind_param("iiii", $servicio_id, $operacion_maestra_id, $usuario_id, $usuario_id);
                    if ($stmt_staff->execute()) {
                        log_debug("   ✅ Creador asignado correctamente a servicio_staff");
                    } else {
                        log_debug("   ❌ Error asignando creador a servicio_staff: " . $stmt_staff->error);
                    }
                    $stmt_staff->close();
                }
            } else {
                log_debug("❌ Error creando Operación Maestra: " . $stmt_maestra->error);
            }
            $stmt_maestra->close();
        } else {
            log_debug("❌ Error preparando SQL de Operación Maestra: " . $conn->error);
        }

        // 🔧 FIX: Forzar actualización del tipo_mantenimiento
        log_debug("🔧 Aplicando FIX: Forzando tipo_mantenimiento correcto...");
        $stmt_fix = $conn->prepare("UPDATE servicios SET tipo_mantenimiento = ? WHERE id = ?");
        $stmt_fix->bind_param("si", $tipo_mantenimiento, $servicio_id);

        if ($stmt_fix->execute()) {
            log_debug("✅ FIX aplicado exitosamente");
        } else {
            log_debug("❌ Error aplicando FIX: " . $stmt_fix->error);
        }
        $stmt_fix->close();

        // ✅ LOG DE TRAZABILIDAD: Registrar estado inicial
        TrazabilidadHelper::registrarTransicionEstado($conn, $servicio_id, $estado_id, $usuario_id);
        log_debug("✅ Trazabilidad inicial registrada");

        // VERIFICACIÓN POST-FIX
        log_debug("🔍🔍🔍 VERIFICACIÓN POST-FIX:");
        $stmt_check = $conn->prepare("SELECT tipo_mantenimiento, LENGTH(tipo_mantenimiento) as len, HEX(tipo_mantenimiento) as hex_val FROM servicios WHERE id = ?");
        $stmt_check->bind_param("i", $servicio_id);
        $stmt_check->execute();
        $result_check = $stmt_check->get_result();
        $row_check = $result_check->fetch_assoc();

        log_debug("   📤 Valor que enviamos: '$tipo_mantenimiento'");
        log_debug("   📥 Valor final en BD: '" . $row_check['tipo_mantenimiento'] . "'");
        log_debug("   📏 Longitud final: " . $row_check['len']);
        log_debug("   🔢 Valor HEX final: " . $row_check['hex_val']);
        log_debug("   ✔️  ¿Son iguales?: " . ($tipo_mantenimiento === $row_check['tipo_mantenimiento'] ? 'SÍ ✅' : 'NO ❌'));

        $stmt_check->close();

        log_debug("📡 Intentando WebSocket y obteniendo datos finales...");
        $servicio_completo_para_respuesta = null;
        try {
            $notifier = new WebSocketNotifier();
            $servicio_completo = $notifier->obtenerServicioCompleto($servicio_id, $conn);

            if ($servicio_completo) {
                $notifier->notificarServicioCreado($servicio_completo, $usuario_id);
                log_debug("✅ WebSocket notificado");
                $servicio_completo_para_respuesta = $notifier->formatearServicio($servicio_completo);
            } else {
                log_debug("⚠️ No se pudo obtener servicio completo");
            }
        } catch (Exception $ws_error) {
            log_debug("⚠️ WebSocket/Fetch error: " . $ws_error->getMessage());
        }

        log_debug("📤 Preparando respuesta JSON con objeto completo...");

        $response_data = [
            'success' => true,
            'message' => 'Servicio creado exitosamente',
            'servicio_id' => $servicio_id,
            'o_servicio' => $o_servicio,
            'data' => $servicio_completo_para_respuesta ?? [
                'id' => (int) $servicio_id,
                'oServicio' => (int) $o_servicio,
                'ordenCliente' => $orden_cliente,
                'fechaIngreso' => $fecha_ingreso_formatted,
                'tipoMantenimiento' => $tipo_mantenimiento,
                'idEquipo' => (int) $id_equipo,
                'centroCosto' => $centro_costo,
                'clienteId' => (int) $cliente_id,
                'autorizadoPor' => (int) $autorizado_por,
                'actividadId' => $actividad_id,
                'cantHora' => 0.0,
                'numTecnicos' => 1,
                'sistemaNombre' => '',
                'estadoId' => (int) $estado_id,
                'numeroServicioFormateado' => sprintf('#%04d', $o_servicio),
            ],
            // '_debug_timers' => array_merge($timers, [
            //     'total_execution' => microtime(true) - $start_time
            // ])
        ];

        log_debug("📤 Respuesta preparada (objeto completo: " . ($servicio_completo_para_respuesta ? 'SÍ' : 'NO') . ")");
        sendJsonResponse($response_data, 201);

        log_debug("✅ sendJsonResponse ejecutado");

    } else {
        log_debug("❌ ERROR EXECUTE: " . $stmt->error);
        log_debug("❌ Error number: " . $stmt->errno);
        throw new Exception('Error execute: ' . $stmt->error);
    }

} catch (Exception $e) {
    log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
    log_debug("❌ Mensaje: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile());
    log_debug("📍 Línea: " . $e->getLine());
    log_debug("📚 Trace: " . $e->getTraceAsString());
    log_debug("📤 Enviando error response...");
    sendJsonResponse(errorResponse($e->getMessage()), 500);
    log_debug("✅ Error response enviado");
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
?>