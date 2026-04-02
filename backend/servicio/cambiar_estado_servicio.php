<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/cambiar_estado_servicio.php', 'change_service_state');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';
    require_once 'helpers/trazabilidad_helper.php';
    require_once '../core/AccountingEngine.php';
    require_once __DIR__ . '/helpers/ServiceStatusValidator.php'; // Pre-flight checks

    // Iniciar transacción para asegurar integridad Senior
    $conn->begin_transaction();

    // PASO 5: Leer y validar input
    $input = json_decode(file_get_contents('php://input'), true);

    // ============================================================================
// FUNCIONES DE VALIDACIÓN (NUEVO)
// ============================================================================

    /**
     * Valida que se cumplan los requisitos de un trigger antes de permitir la transición
     * @param mysqli $conn Conexión a la base de datos
     * @param int $servicio_id ID del servicio
     * @param string $trigger_code Código del trigger a validar
     * @throws Exception si la validación falla
     */
    function validateTriggerRequirements($conn, $servicio_id, $trigger_code)
    {
        if (empty($trigger_code) || $trigger_code === 'MANUAL') {
            return; // No validation needed for manual transitions
        }

        // Configuración de validaciones por tipo de trigger
        $validations = [
            'OS_REPUESTOS' => [
                'table' => 'servicio_repuestos',
                'column' => 'servicio_id',
                'completion_field' => 'suministraron_repuestos',
                'message' => 'No se puede cambiar de estado. Debe agregar y confirmar los repuestos antes de continuar.'
            ],
            'FOTO_SUBIDA' => [
                'table' => 'fotos_servicio',
                'column' => 'servicio_id',
                'completion_field' => 'fotos_confirmadas',
                'message' => 'No se puede cambiar de estado. Debe subir y confirmar las fotos de evidencia antes de continuar.'
            ],
            'FIRMA_CLIENTE' => [
                'table' => 'firmas',
                'column' => 'id_servicio',
                'completion_field' => 'firma_confirmada',
                'message' => 'No se puede cambiar de estado. Debe obtener y confirmar la firma del cliente antes de continuar.'
            ],
            'ASIGNAR_PERSONAL' => [
                'table' => 'servicio_staff',
                'column' => 'servicio_id',
                'completion_field' => 'personal_confirmado',
                'message' => 'No se puede cambiar de estado. Debe asignar y confirmar al técnico antes de continuar.'
            ]
        ];

        if (!isset($validations[$trigger_code])) {
            // Unknown trigger, log warning but allow (for future extensibility)
            error_log("Warning: Unknown trigger code '$trigger_code' for servicio $servicio_id");
            return;
        }

        $config = $validations[$trigger_code];

        // 1. Verificar que existan ítems (repuestos, fotos, firmas, etc.)
        $table = $config['table'];
        $column = $config['column'];
        $stmt = $conn->prepare("SELECT COUNT(*) as count FROM $table WHERE $column = ?");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $data = $result->fetch_assoc();
        $stmt->close();

        if ($data['count'] == 0) {
            throw new Exception($config['message']);
        }

        // 2. Verificar que el usuario haya confirmado (completion flag)
        $completion_field = $config['completion_field'];
        $stmt = $conn->prepare("SELECT $completion_field FROM servicios WHERE id = ?");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $servicio = $result->fetch_assoc();
        $stmt->close();

        if (!$servicio || !$servicio[$completion_field]) {
            throw new Exception($config['message']);
        }
    }



    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $servicio_id = $input['servicio_id'] ?? null;
    $nuevo_estado_id = $input['nuevo_estado_id'] ?? null;
    $es_anulacion = $input['es_anulacion'] ?? false;
    $razon_anulacion = $input['razon_anulacion'] ?? null;
    $saltar_transiciones = $input['saltar_transiciones'] ?? false;
    $trigger_code = $input['trigger_code'] ?? null; // ✅ NUEVO: Código del trigger

    // PASO 6: Validaciones
    if (!$servicio_id || !$nuevo_estado_id) {
        throw new Exception('ID del servicio y nuevo estado son requeridos');
    }

    // PASO 7: Verificar que el servicio existe
    $stmt = $conn->prepare("SELECT estado, anular_servicio FROM servicios WHERE id = ?");
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $servicio = $result->fetch_assoc();
    $stmt->close();

    if (!$servicio) {
        throw new Exception('Servicio no encontrado');
    }

    // PASO 8: Verificar si el servicio ya está anulado
    if ($servicio['anular_servicio'] == 1 && !$es_anulacion) {
        throw new Exception('No se puede cambiar el estado de un servicio anulado');
    }

    // PASO 8.5: Verificar si el estado actual es final (no tiene transiciones de salida)
    // Solo validar si NO es anulación y NO se saltan transiciones
    if (!$es_anulacion && !$saltar_transiciones) {
        $stmt_salidas = $conn->prepare("
            SELECT COUNT(*) as count 
            FROM transiciones_estado 
            WHERE estado_origen_id = ? AND modulo = 'servicio'
        ");
        $stmt_salidas->bind_param("i", $servicio['estado']);
        $stmt_salidas->execute();
        $res_salidas = $stmt_salidas->get_result();
        $salidas = $res_salidas->fetch_assoc();
        $stmt_salidas->close();

        if ($salidas['count'] == 0) {
            // Obtener nombre del estado actual para mensaje más claro
            $stmt_nombre = $conn->prepare("SELECT nombre_estado FROM estados_proceso WHERE id = ?");
            $stmt_nombre->bind_param("i", $servicio['estado']);
            $stmt_nombre->execute();
            $res_nombre = $stmt_nombre->get_result();
            $estado_nombre = $res_nombre->fetch_assoc();
            $stmt_nombre->close();

            $nombre = $estado_nombre['nombre_estado'] ?? 'Estado #' . $servicio['estado'];
            throw new Exception("No se puede cambiar el estado desde '$nombre' porque es un estado final. El servicio ya está cerrado o cancelado.");
        }
    }

    // PASO 9: Verificar transiciones solo si no es anulación y no se saltan validaciones
    if (!$es_anulacion && !$saltar_transiciones) {
        // 9.1: Intento por ID exacto
        $stmt = $conn->prepare("
            SELECT COUNT(*) as count FROM transiciones_estado
            WHERE estado_origen_id = ? AND estado_destino_id = ?
        ");
        $stmt->bind_param("ii", $servicio['estado'], $nuevo_estado_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $transicion_valida = $result->fetch_assoc();
        $stmt->close();

        if ($transicion_valida['count'] == 0) {
            // 9.2: Fallback Robusto: Verificar por Nombres de Estado

            // 9.2.1: Intentar obtener nombres desde la BD usando los IDs
            $stmt_names = $conn->prepare("SELECT id, nombre_estado FROM estados_proceso WHERE id IN (?, ?)");
            $stmt_names->bind_param("ii", $servicio['estado'], $nuevo_estado_id);
            $stmt_names->execute();
            $res_names = $stmt_names->get_result();
            $names_db = [];
            while ($row = $res_names->fetch_assoc()) {
                $names_db[$row['id']] = $row['nombre_estado'];
            }
            $stmt_names->close();

            // 9.2.2: Priorizar nombres pasados por el frontend (clave para casos donde el ID actual fue borrado de la tabla de estados)
            $nombre_origen = $input['estado_origen_nombre'] ?? $names_db[$servicio['estado']] ?? 'N/A';
            $nombre_destino = $input['estado_destino_nombre'] ?? $names_db[$nuevo_estado_id] ?? 'N/A';

            $stmt = $conn->prepare("
                SELECT COUNT(*) as count 
                FROM transiciones_estado t
                JOIN estados_proceso ep_origen ON t.estado_origen_id = ep_origen.id
                JOIN estados_proceso ep_destino ON t.estado_destino_id = ep_destino.id
                WHERE TRIM(UPPER(ep_origen.nombre_estado)) = TRIM(UPPER(?))
                  AND TRIM(UPPER(ep_destino.nombre_estado)) = TRIM(UPPER(?))
                  AND t.modulo = 'servicio'
            ");
            $stmt->bind_param("ss", $nombre_origen, $nombre_destino);
            $stmt->execute();
            $result = $stmt->get_result();
            $transicion_robusta = $result->fetch_assoc();
            $stmt->close();

            if ($transicion_robusta['count'] == 0) {
                // Si llegamos aquí, realmente no hay transición definida ni por ID ni por nombre
                $msg = "Transición de estado no válida. ";
                $msg .= "Origen: $nombre_origen (ID: $servicio[estado]) -> Destino: $nombre_destino (ID: $nuevo_estado_id). ";
                $msg .= "Asegúrese de que exista una transición creada entre estos estados para el módulo 'servicio'.";
                throw new Exception($msg);
            }
        }
    }

    // ✅ VALIDACIÓN DE SALIDA: Verificar campos obligatorios del estado ACTUAL antes de permitir el cambio
    if (!$es_anulacion && !$saltar_transiciones) {
        require_once __DIR__ . '/helpers/validacion_helper.php';
        checkRequiredFields($conn, $servicio_id, $servicio['estado']);

        // ✅ Validar requisitos del disparador (trigger) si el cambio es por trigger
        validateTriggerRequirements($conn, $servicio_id, $trigger_code);

        // ✅ PRE-FLIGHT CHECK: Validar integridad antes de estados finales
        // Verifica: (1) cero operaciones abiertas, (2) fecha_finalizacion registrada, (3) firma válida
        ServiceStatusValidator::validatePreFlight($conn, $servicio_id, $nuevo_estado_id);
    }

    // PASO 10: Preparar datos para actualización

    $campos_actualizacion = ['estado = ?'];
    $tipos_param = 'i';
    $valores_param = [$nuevo_estado_id];

    // Si es anulación, agregar campos adicionales
    if ($es_anulacion) {
        $campos_actualizacion[] = 'anular_servicio = 1';
        $campos_actualizacion[] = 'fecha_finalizacion = NOW()';

        if ($razon_anulacion) {
            $campos_actualizacion[] = 'razon = ?';
            $tipos_param .= 's';
            $valores_param[] = $razon_anulacion;
        }
    }

    // Agregar usuario que realizó el cambio
    $campos_actualizacion[] = 'usuario_ultima_actualizacion = ?';
    $campos_actualizacion[] = 'fecha_actualizacion = NOW()';
    $tipos_param .= 'i';
    $valores_param[] = $currentUser['id'];

    // ✅ NUEVO: Determinar si el nuevo estado es final y actualizar es_finalizado
    require_once __DIR__ . '/helpers/estado_helper.php';

    // -------------------------------------------------------------------------
    // FIN VALIDACIÓN
    // -------------------------------------------------------------------------

    $es_estado_final = esEstadoFinal($conn, $nuevo_estado_id);
    $es_finalizado_valor = ($es_anulacion || $es_estado_final) ? 1 : 0;

    $campos_actualizacion[] = 'es_finalizado = ?';
    $tipos_param .= 'i';
    $valores_param[] = $es_finalizado_valor;

    // Agregar ID del servicio al final
    $tipos_param .= 'i';
    $valores_param[] = $servicio_id;

    // PASO 11: Ejecutar actualización
    $sql = "UPDATE servicios SET " . implode(', ', $campos_actualizacion) . " WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param($tipos_param, ...$valores_param);

    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        $stmt->close();

        // ✅ LOG DE TRAZABILIDAD: Registrar cambio de estado
        TrazabilidadHelper::registrarTransicionEstado($conn, $servicio_id, $nuevo_estado_id, $currentUser['id']);

        // PASO 12: Obtener info del nuevo estado
        $stmt = $conn->prepare("SELECT nombre_estado, estado_base_codigo FROM estados_proceso WHERE id = ?");
        $stmt->bind_param("i", $nuevo_estado_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $estado_info = $result->fetch_assoc();
        $stmt->close();

        $nombre_estado = $estado_info['nombre_estado'] ?? 'Estado #' . $nuevo_estado_id;
        $estado_base = $estado_info['estado_base_codigo'] ?? '';

        // ✅ HOOK CONTABLE: Si el nuevo estado es LEGALIZADO, realizar Snapshot
        if ($estado_base === 'LEGALIZADO') {
            try {
                $snapshotSuccess = AccountingEngine::snapshotService($conn, $servicio_id);
                if (!$snapshotSuccess) {
                    throw new Exception("Error interno en AccountingEngine (Snapshot fallido).");
                }
            } catch (Exception $accEx) {
                // EXCEPCIÓN CRÍTICA: La legalización NO puede ocurrir sin snapshot
                throw new Exception("ERROR CONTABLE: No se pudo generar el snapshot financiero ({$accEx->getMessage()}). La legalización ha sido abortada por seguridad de datos.");
            }
        }

        // Finalizar transacción exitosamente
        $conn->commit();

        // PASO 13: Respuesta exitosa con contexto de usuario
        $mensaje = $es_anulacion
            ? "Servicio anulado y movido al estado: $nombre_estado"
            : "Estado actualizado exitosamente a: $nombre_estado";

        sendJsonResponse([
            'success' => true,
            'message' => $mensaje,
            'data' => [
                'servicio_id' => $servicio_id,
                'nuevo_estado_id' => $nuevo_estado_id,
                'nombre_estado' => $nombre_estado,
                'es_anulacion' => $es_anulacion,
                'affected_rows' => $affected_rows,
                'updated_by_user' => $currentUser['usuario'],
                'updated_by_role' => $currentUser['rol']
            ]
        ]);

    } else {
        throw new Exception('Error al actualizar el estado: ' . $stmt->error);
    }

} catch (Exception $e) {
    // Rollback por seguridad ante cualquier error
    if (isset($conn) && $conn->connect_errno == 0) {
        $conn->rollback();
    }
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($stmt) && $stmt !== null) {
    $stmt->close();
}
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>