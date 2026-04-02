<?php
// crear_firma.php - Protegido con JWT
// FINAL: Staff de usuarios, Funcionario de funcionario

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_crear_firma.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}



register_shutdown_function(function () {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("ERROR FATAL: " . $error['message']);
        log_debug("Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function ($e) {
    log_debug("EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("NUEVA REQUEST CREAR FIRMA");
log_debug("========================================");
log_debug("IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

try {
    require_once '../login/auth_middleware.php';
    require_once '../workflow/workflow_helper.php';
    log_debug("auth_middleware y workflow_helper cargados");

    $currentUser = requireAuth();
    log_debug("Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/firma/crear_firma.php', 'create_firma');
    log_debug("Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("Requiriendo conexión...");
    require '../conexion.php';
    log_debug("conexion.php cargado");

    $raw_input = file_get_contents('php://input');
    log_debug("Raw input length: " . strlen($raw_input));

    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        log_debug("ERROR JSON: " . json_last_error_msg());
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    log_debug("JSON decodificado correctamente");

    // Extraer campos obligatorios
    $id_servicio = isset($input['id_servicio']) ? intval($input['id_servicio']) : null;
    $id_staff_entrega = isset($input['id_staff_entrega']) ? intval($input['id_staff_entrega']) : null;
    $id_funcionario_recibe = isset($input['id_funcionario_recibe']) ? intval($input['id_funcionario_recibe']) : null;
    $firma_staff_base64 = $input['firma_staff_base64'] ?? null;
    $firma_funcionario_base64 = $input['firma_funcionario_base64'] ?? null;

    // Campos opcionales
    $nota_entrega = $input['nota_entrega'] ?? null;
    $nota_recepcion = $input['nota_recepcion'] ?? null;
    $participantes_servicio = $input['participantes_servicio'] ?? null;

    log_debug("Variables extraídas:");
    log_debug("   id_servicio: " . ($id_servicio ?? 'NULL'));
    log_debug("   id_staff_entrega: " . ($id_staff_entrega ?? 'NULL'));
    log_debug("   id_funcionario_recibe: " . ($id_funcionario_recibe ?? 'NULL'));
    log_debug("   firma_staff_base64 length: " . (isset($firma_staff_base64) ? strlen($firma_staff_base64) : 0));
    log_debug("   firma_funcionario_base64 length: " . (isset($firma_funcionario_base64) ? strlen($firma_funcionario_base64) : 0));
    log_debug("   nota_entrega: " . ($nota_entrega ?? 'NULL'));
    log_debug("   nota_recepcion: " . ($nota_recepcion ?? 'NULL'));

    // Validar campos obligatorios
    $errores = [];
    if (!$id_servicio)
        $errores[] = 'id_servicio';
    if (!$id_staff_entrega)
        $errores[] = 'id_staff_entrega';
    if (!$id_funcionario_recibe)
        $errores[] = 'id_funcionario_recibe';
    if (!$firma_staff_base64 || trim($firma_staff_base64) === '')
        $errores[] = 'firma_staff_base64';
    if (!$firma_funcionario_base64 || trim($firma_funcionario_base64) === '')
        $errores[] = 'firma_funcionario_base64';

    if (!empty($errores)) {
        log_debug("Faltan campos obligatorios: " . implode(', ', $errores));
        throw new Exception('Campos obligatorios faltantes: ' . implode(', ', $errores));
    }

    log_debug("Validación de campos obligatorios OK");

    // Validar que el servicio existe
    log_debug("Validando servicio ID: $id_servicio");
    $stmt = $conn->prepare("SELECT id, o_servicio FROM servicios WHERE id = ?");
    if (!$stmt) {
        log_debug("Error preparando query servicio: " . $conn->error);
        throw new Exception('Error preparando query servicio');
    }
    $stmt->bind_param("i", $id_servicio);
    $stmt->execute();
    $result = $stmt->get_result();
    $servicio = $result->fetch_assoc();

    if (!$servicio) {
        log_debug("Servicio no encontrado con ID: $id_servicio");
        sendJsonResponse(errorResponse('Servicio no encontrado'), 404);
    }
    log_debug("Servicio encontrado - o_servicio: " . $servicio['o_servicio']);

    // FINAL: Validar que el staff existe (puede ser Staff técnico o Usuario administrador)
    $is_staff_manual = $id_staff_entrega > 1000000;
    $real_id = $is_staff_manual ? ($id_staff_entrega - 1000000) : $id_staff_entrega;

    if ($is_staff_manual) {
        log_debug("Validando Staff técnico ID real: $real_id (ID recibido: $id_staff_entrega)");
        $stmt = $conn->prepare("SELECT id, CONCAT(first_name, ' ', last_name) as NOMBRE_USER FROM staff WHERE id = ?");
    } else {
        log_debug("Validando Usuario administrador ID: $id_staff_entrega");
        $stmt = $conn->prepare("SELECT id, NOMBRE_USER FROM usuarios WHERE id = ?");
    }

    if (!$stmt) {
        log_debug("Error preparando query staff: " . $conn->error);
        throw new Exception('Error preparando query staff');
    }
    $stmt->bind_param("i", $real_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $staff = $result->fetch_assoc();

    if (!$staff) {
        $tipo = $is_staff_manual ? 'Staff técnico' : 'Usuario administrador';
        log_debug("$tipo no encontrado con ID: $real_id");
        sendJsonResponse(errorResponse("$tipo no encontrado"), 404);
    }
    log_debug("$tipo encontrado: " . $staff['NOMBRE_USER']);

    // FINAL: Validar que el funcionario existe en tabla "funcionario"
    log_debug("Validando funcionario (funcionario_recibe) ID: $id_funcionario_recibe");
    $stmt = $conn->prepare("SELECT id, nombre FROM funcionario WHERE id = ?");
    if (!$stmt) {
        log_debug("Error preparando query funcionario: " . $conn->error);
        throw new Exception('Error preparando query funcionario');
    }
    $stmt->bind_param("i", $id_funcionario_recibe);
    $stmt->execute();
    $result = $stmt->get_result();
    $funcionario = $result->fetch_assoc();

    if (!$funcionario) {
        log_debug("Funcionario (funcionario_recibe) no encontrado con ID: $id_funcionario_recibe");
        sendJsonResponse(errorResponse('Funcionario (funcionario_recibe) no encontrado'), 404);
    }
    log_debug("Funcionario (funcionario_recibe) encontrado: " . $funcionario['nombre']);

    // Validar que no exista ya una firma para este servicio
    log_debug("Verificando firmas existentes para servicio: $id_servicio");
    $stmt = $conn->prepare("SELECT id FROM firmas WHERE id_servicio = ?");
    if (!$stmt) {
        log_debug("Error preparando query verificación: " . $conn->error);
        throw new Exception('Error preparando query verificación');
    }
    $stmt->bind_param("i", $id_servicio);
    $stmt->execute();
    $result = $stmt->get_result();
    $firma_existente = $result->fetch_assoc();

    if ($firma_existente) {
        log_debug("Ya existe una firma para este servicio (ID: " . $firma_existente['id'] . ")");
        sendJsonResponse(errorResponse('Ya existe una firma para este servicio'), 409);
    }
    log_debug("No hay firmas previas para este servicio");

    // Preparar INSERT
    $sql = "INSERT INTO firmas (
                id_servicio, 
                id_staff_entrega, 
                id_funcionario_recibe, 
                firma_staff_base64, 
                firma_funcionario_base64,
                nota_entrega,
                nota_recepcion,
                participantes_servicio,
                created_at,
                updated_at
            ) VALUES (
                ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW()
            )";

    log_debug("SQL preparado");
    log_debug("Preparando statement...");

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        log_debug("ERROR PREPARE: " . $conn->error);
        throw new Exception('Error prepare: ' . $conn->error);
    }
    log_debug("Statement preparado correctamente");

    log_debug("Binding params con tipo: iiisssss (8 params)");
    log_debug("Parámetros a bindear:");
    log_debug("   1. id_servicio (i): $id_servicio");
    log_debug("   2. id_staff_entrega (i): $id_staff_entrega");
    log_debug("   3. id_funcionario_recibe (i): $id_funcionario_recibe");
    log_debug("   4. firma_staff_base64 (s): " . strlen($firma_staff_base64) . " chars");
    log_debug("   5. firma_funcionario_base64 (s): " . strlen($firma_funcionario_base64) . " chars");
    log_debug("   6. nota_entrega (s): " . ($nota_entrega ?? 'NULL'));
    log_debug("   7. nota_recepcion (s): " . ($nota_recepcion ?? 'NULL'));
    log_debug("   8. participantes_servicio (s): " . ($participantes_servicio ?? 'NULL'));

    $bind_result = $stmt->bind_param(
        "iiisssss",
        $id_servicio,
        $id_staff_entrega,
        $id_funcionario_recibe,
        $firma_staff_base64,
        $firma_funcionario_base64,
        $nota_entrega,
        $nota_recepcion,
        $participantes_servicio
    );

    log_debug("bind_param resultado: " . ($bind_result ? 'TRUE' : 'FALSE'));

    if (!$bind_result) {
        log_debug("ERROR BIND: " . $stmt->error);
        throw new Exception('Error bind: ' . $stmt->error);
    }

    log_debug("Bind exitoso");
    log_debug("Ejecutando INSERT...");

    if ($stmt->execute()) {
        $firma_id = $conn->insert_id;
        log_debug("INSERT EXITOSO!");
        log_debug("Firma creada con ID: $firma_id");

        // AUTOMATIZACIÓN: Marcar firma_confirmada = 1 en la tabla "servicios"
        // para que la interfaz sepa que ya no se requiere acción manual.
        $stmt_conf = $conn->prepare("UPDATE servicios SET firma_confirmada = 1 WHERE id = ?");
        if ($stmt_conf) {
            $stmt_conf->bind_param("i", $id_servicio);
            $stmt_conf->execute();
            log_debug("Servicio marcado como FIRMA_CONFIRMADA automaticamente al guardar firma.");
        }

        log_debug("Preparando respuesta JSON...");

        $response_data = [
            'success' => true,
            'message' => 'Firma creada exitosamente',
            'firma_id' => $firma_id,
            'data' => [
                'id' => (int) $firma_id,
                'idServicio' => (int) $id_servicio,
                'oServicio' => (int) $servicio['o_servicio'],
                'idStaffEntrega' => (int) $id_staff_entrega,
                'staffNombre' => $staff['NOMBRE_USER'],
                'idFuncionarioRecibe' => (int) $id_funcionario_recibe,
                'funcionarioNombre' => $funcionario['nombre'],
                'notaEntrega' => $nota_entrega,
                'notaRecepcion' => $nota_recepcion,
                'createdAt' => date('Y-m-d H:i:s')
            ]
        ];

        // --------------------------------------------------------------------
        // LÓGICA DE AUTO-TRANSICIÓN (TRIGGER: FIRMA_CLIENTE)
        // --------------------------------------------------------------------
        try {
            log_debug("Iniciando verificación de Auto-Transición...");

            // Usamos el nuevo WorkflowHelper centralizado
            $workflow_res = WorkflowHelper::ejecutarTrigger($conn, $id_servicio, 'FIRMA_CLIENTE', $currentUser['id']);

            log_debug("Resultado Workflow: " . json_encode($workflow_res));

            if ($workflow_res['success']) {
                $response_data['auto_transition'] = [
                    'triggered' => isset($workflow_res['new_state']),
                    'new_state_id' => $workflow_res['new_state'] ?? null,
                    'message' => $workflow_res['message']
                ];
            } else {
                $response_data['auto_transition'] = [
                    'triggered' => true,
                    'success' => false,
                    'warning' => "Firma guardada, pero no se pudo avanzar estado: " . $workflow_res['message']
                ];
            }

        } catch (Exception $e_trigger) {
            log_debug("Error en bloque Auto-Transición: " . $e_trigger->getMessage());
        }
        // --------------------------------------------------------------------


        log_debug("Respuesta preparada (size: " . strlen(json_encode($response_data)) . " bytes)");
        log_debug("Enviando respuesta JSON...");

        sendJsonResponse($response_data, 201);

        log_debug("sendJsonResponse ejecutado");
    } else {
        log_debug("ERROR EXECUTE: " . $stmt->error);
        log_debug("Error number: " . $stmt->errno);
        throw new Exception('Error execute: ' . $stmt->error);
    }
} catch (Exception $e) {
    log_debug("EXCEPTION CAPTURADA");
    log_debug("Mensaje: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile());
    log_debug("Línea: " . $e->getLine());
    log_debug("Trace: " . $e->getTraceAsString());
    log_debug("Enviando error response...");
    sendJsonResponse(errorResponse($e->getMessage()), 500);
    log_debug("Error response enviado");
} finally {
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
