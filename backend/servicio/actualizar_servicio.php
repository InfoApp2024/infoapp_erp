<?php
// actualizar_servicio.php - Protegido con JWT
require_once '../login/auth_middleware.php';

try {
    // PASO 1: REQUIERE AUTENTICACIÓN - Solo usuarios autenticados pueden actualizar servicios
    $currentUser = requireAuth();

    // PASO 2: Log del acceso
    logAccess($currentUser, '/actualizar_servicio.php', 'update_service');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Lógica original del endpoint
    require '../conexion.php';
    require 'WebSocketNotifier.php';
    require_once '../workflow/workflow_helper.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    // Extraer variables
    $servicio_id = $input['servicio_id'] ?? null;
    $orden_cliente = $input['orden_cliente'] ?? null;
    $fecha_ingreso = $input['fecha_ingreso'] ?? null;
    $tipo_mantenimiento = $input['tipo_mantenimiento'] ?? null;
    $centro_costo = $input['centro_costo'] ?? null;
    $autorizado_por = $input['autorizado_por'] ?? null;
    $id_equipo = $input['id_equipo'] ?? null;
    $suministraron_repuestos = isset($input['suministraron_repuestos']) ? $input['suministraron_repuestos'] : null;
    $fecha_finalizacion = $input['fecha_finalizacion'] ?? null;
    $anular_servicio = $input['anular_servicio'] ?? 0;
    $razon = $input['razon'] ?? null;
    $actividad_id = isset($input['actividad_id']) ? intval($input['actividad_id']) : null;
    $cliente_id = isset($input['cliente_id']) ? intval($input['cliente_id']) : null; // ✅ NUEVO

    // NUEVO: Usar el usuario autenticado desde JWT (no del request)
    $usuario_id = $currentUser['id'];

    // DEBUG
    error_log("DEBUG ACTUALIZAR: Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $usuario_id . ")");
    error_log("DEBUG ACTUALIZAR: Actividad ID: " . ($actividad_id ?? 'NULL'));

    if (!$servicio_id) {
        throw new Exception('ID del servicio es requerido');
    }

    // Verificar que el servicio existe, su estado de anulación y estado base comercial
    $stmt_verificar = $conn->prepare("
        SELECT s.anular_servicio, ep.estado_base_codigo 
        FROM servicios s 
        LEFT JOIN estados_proceso ep ON s.estado = ep.id 
        WHERE s.id = ?
    ");
    $stmt_verificar->bind_param("i", $servicio_id);
    $stmt_verificar->execute();
    $result_verificar = $stmt_verificar->get_result();
    $row_verificar = $result_verificar->fetch_assoc();
    $stmt_verificar->close();

    if (!$row_verificar) {
        throw new Exception('Servicio no encontrado con ID: ' . $servicio_id);
    }

    // ✅ NUEVO: Bloquear edición si el servicio está anulado
    if ((int) $row_verificar['anular_servicio'] === 1) {
        // Permitir solo si es la solicitud de anulación misma (para evitar bloqueo recursivo si se llama desde anular)
        // Pero anular_servicio.php usa UPDATE directo, asique aquí bloqueamos todo intento de UPDATE normal.
        throw new Exception('No se puede editar un servicio que ha sido anulado.');
    }

    // ✅ NUEVO: Lógica de bloqueo de edición basada en estados y permisos
    $estado_base = strtoupper(trim($row_verificar['estado_base_codigo'] ?? ''));
    
    // 1. Estados terminales absolutos (Inmutables por defecto)
    $esTerminal = in_array($estado_base, ['LEGALIZADO', 'CANCELADO']);
    
    // 2. Estados finales intermedios (Cerrados por defecto)
    $esFinalIntermedio = in_array($estado_base, ['FINALIZADO', 'CERRADO']);

    if (($esTerminal || $esFinalIntermedio) && $anular_servicio !== 1) {
        // Verificar si el usuario tiene permiso de bypass
        $sqlPerm = "SELECT can_edit_closed_ops FROM usuarios WHERE id = ? LIMIT 1";
        $stmtPerm = $conn->prepare($sqlPerm);
        $stmtPerm->bind_param("i", $currentUser['id']);
        $stmtPerm->execute();
        $resPerm = $stmtPerm->get_result();
        $canEdit = false;
        if ($rowP = $resPerm->fetch_assoc()) {
            $canEdit = ((int)$rowP['can_edit_closed_ops'] === 1);
        }
        $stmtPerm->close();

        if (!$canEdit) {
            $msg = $esTerminal ? "terminal ($estado_base)" : "'$estado_base'";
            throw new Exception("No tiene permisos para editar un servicio en estado $msg.");
        }
        
        error_log("DEBUG: Bypass de edición permitido por 'can_edit_closed_ops' en estado " . ($esTerminal ? "terminal " : "") . "'$estado_base'");
    }

    // Construir la consulta SQL dinámicamente
    $campos_actualizar = [];
    $valores = [];
    $tipos = '';

    if ($orden_cliente !== null) {
        $campos_actualizar[] = "orden_cliente = ?";
        $valores[] = $orden_cliente;
        $tipos .= 's';
    }

    if ($fecha_ingreso !== null) {
        $fecha_ingreso_formatted = date('Y-m-d H:i:s', strtotime($fecha_ingreso));
        $campos_actualizar[] = "fecha_ingreso = ?";
        $valores[] = $fecha_ingreso_formatted;
        $tipos .= 's';
    }

    if ($tipo_mantenimiento !== null) {
        $tipo_limpio = trim(strtolower($tipo_mantenimiento));
        $campos_actualizar[] = "tipo_mantenimiento = ?";
        $valores[] = $tipo_limpio;
        $tipos .= 's';
    }
    if ($centro_costo !== null) {
        $centro_limpio = trim(strtolower($centro_costo));
        $campos_actualizar[] = "centro_costo = ?";
        $valores[] = $centro_limpio;
        $tipos .= 's';
    }


    if ($autorizado_por !== null) {
        $campos_actualizar[] = "autorizado_por = ?";
        $valores[] = $autorizado_por;
        $tipos .= 'i';
    }

    if ($id_equipo !== null) {
        // Si se cambia el equipo, actualizar también los datos del equipo
        $stmt_equipo = $conn->prepare("SELECT nombre_empresa, placa FROM equipos WHERE id = ?");
        $stmt_equipo->bind_param("i", $id_equipo);
        $stmt_equipo->execute();
        $result_equipo = $stmt_equipo->get_result();
        $equipo = $result_equipo->fetch_assoc();
        $stmt_equipo->close();

        if ($equipo) {
            $campos_actualizar[] = "id_equipo = ?";
            $valores[] = $id_equipo;
            $tipos .= 'i';

            $campos_actualizar[] = "nombre_emp = ?";
            $valores[] = $equipo['nombre_empresa'];
            $tipos .= 's';

            $campos_actualizar[] = "placa = ?";
            $valores[] = $equipo['placa'];
            $tipos .= 's';
        } else {
            throw new Exception('Equipo no encontrado con ID: ' . $id_equipo);
        }
    }

    // Actualizar actividad_id
    if ($actividad_id !== null) {
        $campos_actualizar[] = "actividad_id = ?";
        $valores[] = $actividad_id;
        $tipos .= 'i';
        error_log("DEBUG: Actualizando actividad_id a: " . $actividad_id);
    }

    if ($cliente_id !== null) {
        $campos_actualizar[] = "cliente_id = ?";
        $valores[] = $cliente_id;
        $tipos .= 'i';
        error_log("DEBUG: Actualizando cliente_id a: " . $cliente_id);
    }

    if ($suministraron_repuestos !== null) {
        $campos_actualizar[] = "suministraron_repuestos = ?";
        $valores[] = (int) $suministraron_repuestos;
        $tipos .= 'i';
        error_log("DEBUG: Actualizando suministraron_repuestos a: " . $suministraron_repuestos);
    }

    if ($fecha_finalizacion !== null) {
        $fecha_finalizacion_formatted = date('Y-m-d H:i:s', strtotime($fecha_finalizacion));
        $campos_actualizar[] = "fecha_finalizacion = ?";
        $valores[] = $fecha_finalizacion_formatted;
        $tipos .= 's';
    }

    $campos_actualizar[] = "anular_servicio = ?";
    $valores[] = $anular_servicio;
    $tipos .= 'i';

    if ($razon !== null) {
        $campos_actualizar[] = "razon = ?";
        $valores[] = $razon;
        $tipos .= 's';
    }

    // Agregar fecha de actualización y usuario autenticado
    $campos_actualizar[] = "fecha_actualizacion = NOW()";
    $campos_actualizar[] = "usuario_ultima_actualizacion = ?";
    $valores[] = $usuario_id;
    $tipos .= 'i';

    // Agregar el ID del servicio al final
    $valores[] = $servicio_id;
    $tipos .= 'i';

    // Construir y ejecutar la consulta
    $sql = "UPDATE servicios SET " . implode(', ', $campos_actualizar) . " WHERE id = ?";

    error_log("DEBUG UPDATE: SQL: " . $sql);
    error_log("DEBUG UPDATE: Valores: " . json_encode($valores));
    error_log("DEBUG UPDATE: Tipos: " . $tipos);

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Error preparando consulta: ' . $conn->error);
    }

    $stmt->bind_param($tipos, ...$valores);

    if ($stmt->execute()) {
        $campos_actualizados_count = count($campos_actualizar) - 2; // -2 porque fecha_actualizacion y usuario son automáticos

        // Verificar qué se actualizó
        $stmt_verify = $conn->prepare("SELECT id, o_servicio, actividad_id, usuario_creador, usuario_ultima_actualizacion, fecha_actualizacion FROM servicios WHERE id = ?");
        $stmt_verify->bind_param("i", $servicio_id);
        $stmt_verify->execute();
        $verify_result = $stmt_verify->get_result();
        $updated_data = $verify_result->fetch_assoc();
        $stmt_verify->close();

        error_log("DEBUG: Datos después del UPDATE: " . json_encode($updated_data));

        // ✅ NUEVO: Auto-bloquear repuestos (marcar desbloqueos como usados)
        $stmt_lock = $conn->prepare("UPDATE servicios_desbloqueos_repuestos SET usado = 1 WHERE servicio_id = ? AND usado = 0");
        if ($stmt_lock) {
            $stmt_lock->bind_param("i", $servicio_id);
            $stmt_lock->execute();
            $stmt_lock->close();
        }

        // ✅ NUEVO: Ejecutar disparadores automáticos de Workflow al guardar
        $workflow_res = WorkflowHelper::evaluarTriggersAutomaticos($conn, $servicio_id, $usuario_id);
        error_log("DEBUG WORKFLOW: Resultado: " . json_encode($workflow_res));

        // Obtener servicio completo actualizado y notificar WebSocket
        try {
            $notifier = new WebSocketNotifier();
            $servicio_actualizado = $notifier->obtenerServicioCompleto($servicio_id, $conn);

            if ($servicio_actualizado) {
                // Notificar vía WebSocket
                $notifier->notificarServicioActualizado(
                    $servicio_actualizado,
                    $usuario_id
                );

                // Obtener nombre de la actividad si existe
                $actividad_nombre = null;
                if ($servicio_actualizado['actividad_id']) {
                    $stmt_actividad = $conn->prepare("SELECT actividad FROM actividades_estandar WHERE id = ?");
                    $stmt_actividad->bind_param("i", $servicio_actualizado['actividad_id']);
                    $stmt_actividad->execute();
                    $result_actividad = $stmt_actividad->get_result();
                    $actividad_data = $result_actividad->fetch_assoc();
                    if ($actividad_data) {
                        $actividad_nombre = $actividad_data['actividad'];
                    }
                    $stmt_actividad->close();
                }

                // PASO 5: Respuesta con contexto de usuario autenticado
                sendJsonResponse([
                    'success' => true,
                    'message' => 'Servicio actualizado exitosamente',
                    'data' => [
                        'id' => (int) $servicio_actualizado['id'],
                        'oServicio' => (int) $servicio_actualizado['o_servicio'],
                        'ordenCliente' => $servicio_actualizado['orden_cliente'],
                        'fechaIngreso' => $servicio_actualizado['fecha_ingreso'],
                        'fechaFinalizacion' => $servicio_actualizado['fecha_finalizacion'],
                        'tipoMantenimiento' => $servicio_actualizado['tipo_mantenimiento'],
                        'idEquipo' => (int) $servicio_actualizado['id_equipo'],
                        'centroCosto' => $servicio_actualizado['centro_costo'] ?? null,
                        'clienteId' => $servicio_actualizado['cliente_id'] ? (int) $servicio_actualizado['cliente_id'] : null,
                        'clienteNombre' => $servicio_actualizado['cliente_nombre'] ?? null,
                        'equipoNombre' => $servicio_actualizado['equipo_nombre'] ?? $servicio_actualizado['nombre_emp'],
                        'placa' => $servicio_actualizado['placa'],
                        'nombreEmp' => $servicio_actualizado['nombre_emp'],
                        'autorizadoPor' => $servicio_actualizado['autorizado_por'] ? (int) $servicio_actualizado['autorizado_por'] : null,
                        'funcionarioNombre' => $servicio_actualizado['funcionario_nombre'] ?? null,
                        'actividadId' => $servicio_actualizado['actividad_id'] ? (int) $servicio_actualizado['actividad_id'] : null,
                        'actividadNombre' => $actividad_nombre,
                        'cantHora' => isset($servicio_actualizado['cant_hora']) ? (float) $servicio_actualizado['cant_hora'] : 0.0,
                        'numTecnicos' => isset($servicio_actualizado['num_tecnicos']) ? (int) $servicio_actualizado['num_tecnicos'] : 1,
                        'sistemaNombre' => $servicio_actualizado['sistema_nombre'] ?? '',
                        'estadoId' => (int) $servicio_actualizado['estado'],
                        'estadoNombre' => $servicio_actualizado['estado_nombre'] ?? null,
                        'observaciones' => $servicio_actualizado['observaciones'] ?? null,
                        'fechaCreacion' => $servicio_actualizado['fecha_registro'] ?? null,
                        'fechaActualizacion' => $servicio_actualizado['fecha_actualizacion'] ?? null,
                        'estaAnulado' => (bool) ($servicio_actualizado['anular_servicio'] ?? false),
                        'estaFinalizado' => isset($servicio_actualizado['fecha_finalizacion']) && $servicio_actualizado['fecha_finalizacion'] !== null,
                        'tieneRepuestos' => (bool) ($servicio_actualizado['suministraron_repuestos'] ?? false),
                        'suministraron_repuestos' => (bool) ($servicio_actualizado['suministraron_repuestos'] ?? false), // ✅ Clave para el modelo Flutter
                        'razon' => $servicio_actualizado['razon'] ?? null,
                        'usuarioCreador' => $servicio_actualizado['usuario_creador'] ? (int) $servicio_actualizado['usuario_creador'] : null,
                        'usuarioUltimaActualizacion' => $usuario_id,
                        'numeroServicioFormateado' => sprintf('#%04d', $servicio_actualizado['o_servicio']),
                        // NUEVO: Información del usuario autenticado
                        'updated_by_user' => $currentUser['usuario'],
                        'updated_by_role' => $currentUser['rol'],
                    ],
                    'campos_actualizados' => $campos_actualizados_count,
                    'servicio_id' => $servicio_id,
                    'usuario_actualizado_por' => $usuario_id,
                    'actividad_actualizada' => $actividad_id !== null,
                    'websocket_notificado' => true,
                    'websocket_disponible' => $notifier->verificarConexion(),
                    'campos_modificados' => array_slice($campos_actualizar, 0, -2),
                    'workflow' => $workflow_res // ✅ NUEVO: Resultado para el frontend
                ], 200);
            } else {
                // Respuesta básica si no se puede obtener servicio completo
                sendJsonResponse([
                    'success' => true,
                    'message' => 'Servicio actualizado exitosamente',
                    'campos_actualizados' => $campos_actualizados_count,
                    'servicio_id' => $servicio_id,
                    'actividad_id' => $actividad_id,
                    'usuario_actualizado_por' => $usuario_id,
                    'updated_by_user' => $currentUser['usuario'],
                    'updated_by_role' => $currentUser['rol'],
                    'websocket_notificado' => false,
                    'websocket_error' => 'No se pudo obtener servicio completo'
                ], 200);
            }
        } catch (Exception $ws_error) {
            // Si falla WebSocket, continuar con respuesta normal
            error_log("Error WebSocket en actualizar_servicio: " . $ws_error->getMessage());

            sendJsonResponse([
                'success' => true,
                'message' => 'Servicio actualizado exitosamente',
                'campos_actualizados' => $campos_actualizados_count,
                'servicio_id' => $servicio_id,
                'actividad_id' => $actividad_id,
                'usuario_actualizado_por' => $usuario_id,
                'updated_by_user' => $currentUser['usuario'],
                'updated_by_role' => $currentUser['rol'],
                'websocket_notificado' => false,
                'websocket_error' => $ws_error->getMessage()
            ], 200);
        }
    } else {
        throw new Exception('Error ejecutando consulta: ' . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>