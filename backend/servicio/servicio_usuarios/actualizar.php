<?php

/**
 * PUT/POST /servicio_usuarios/actualizar.php
 * 
 * Endpoint para actualizar personal (usuarios) y responsable de un servicio
 * ✅ VERSIÓN FINAL: Actualiza servicio_staff Y servicios.responsable_id
 * TODO EN UNA TRANSACCIÓN ATÓMICA
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_actualizar_usuarios.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

header('Content-Type: application/json; charset=utf-8');

require_once '../../login/auth_middleware.php';

try {
    // PASO 1: Autenticación
    $currentUser = requireAuth();
    logAccess($currentUser, '/servicio/servicio_usuarios/actualizar.php', 'update_service_users');

    log_debug("========================================");
    log_debug("🆕 ACTUALIZAR USUARIOS Y RESPONSABLE (ENDPOINT USUARIOS)");
    log_debug("Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    // PASO 2: Validar método
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido");
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 3: Conexión
    require '../../conexion.php';

    // PASO 4: Leer datos
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $data = [];

    if (strpos($contentType, 'application/json') !== false) {
        $input = file_get_contents("php://input");
        $data = json_decode($input, true);

        if (!$data && !empty($input)) {
            log_debug("❌ JSON inválido");
            sendJsonResponse(errorResponse('JSON inválido'), 400);
        }
    } else {
        $data = !empty($_POST) ? $_POST : $_GET;
    }

    if (empty($data)) {
        log_debug("❌ No hay datos");
        sendJsonResponse(errorResponse('No se recibieron datos'), 400);
    }

    // PASO 5: Validar servicio_id
    if (!isset($data['servicio_id']) || empty($data['servicio_id'])) {
        log_debug("❌ servicio_id faltante");
        sendJsonResponse(errorResponse('servicio_id es requerido'), 400);
    }

    $servicio_id = intval($data['servicio_id']);
    log_debug("🔍 Servicio ID: $servicio_id");

    // Verificar servicio
    $sqlServiceCheck = "SELECT id FROM servicios WHERE id = ? LIMIT 1";
    $stmtCheck = $conn->prepare($sqlServiceCheck);
    $stmtCheck->bind_param("i", $servicio_id);
    $stmtCheck->execute();

    if ($stmtCheck->get_result()->num_rows === 0) {
        log_debug("❌ Servicio no encontrado");
        sendJsonResponse(errorResponse('Servicio no encontrado'), 404);
    }
    $stmtCheck->close();

    log_debug("✅ Servicio verificado");
    
    // ✅ PASO 5.5: Verificar estado del servicio para bloqueo de edición
    $sqlState = "SELECT e.estado_base_codigo 
                FROM servicios s
                INNER JOIN estados_proceso e ON s.estado = e.id
                WHERE s.id = ? 
                LIMIT 1";
    $stmtState = $conn->prepare($sqlState);
    $stmtState->bind_param("i", $servicio_id);
    $stmtState->execute();
    $resState = $stmtState->get_result();
    
    if ($rowState = $resState->fetch_assoc()) {
        $estado_base = $rowState['estado_base_codigo'];
        $finalStates = ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'];
        
        if (in_array($estado_base, $finalStates)) {
             // ? CONSULTA DE SEGURIDAD: Verificar si el usuario tiene permiso de bypass
             $sqlPerm = "SELECT can_edit_closed_ops FROM usuarios WHERE id = ? LIMIT 1";
             $stmtPerm = $conn->prepare($sqlPerm);
             $stmtPerm->bind_param("i", $currentUser['id']);
             $stmtPerm->execute();
             $resPerm = $stmtPerm->get_result();
             $canEdit = false;
             if ($rowPerm = $resPerm->fetch_assoc()) {
                 $canEdit = ((int)$rowPerm['can_edit_closed_ops'] === 1);
             }
             $stmtPerm->close();

             $isTerminal = in_array($estado_base, ['LEGALIZADO', 'CANCELADO']);

             if ($isTerminal || !$canEdit) {
                 log_debug("❌ Intento de editar personal en servicio con estado final: $estado_base (Permiso bypass: " . ($canEdit ? 'SÍ' : 'NO') . ")");
                 sendJsonResponse(errorResponse("No se puede editar el personal de un servicio en estado final ($estado_base)"), 403);
             } else {
                 log_debug("🔓 Bypass de edición de personal permitido por 'can_edit_closed_ops' en estado $estado_base");
             }
        }
    }
    $stmtState->close();

    // PASO 6: Obtener usuario_ids
    $usuario_ids = [];

    if (isset($data['usuario_ids']) && is_array($data['usuario_ids']) && !empty($data['usuario_ids'])) {
        log_debug("✅ Detectado: usuario_ids");
        // Filtrar, únicos y re-indexar
        $usuario_ids = array_values(array_unique(array_filter(array_map('intval', $data['usuario_ids']))));
    } elseif (isset($data['staff_ids']) && is_array($data['staff_ids']) && !empty($data['staff_ids'])) {
        log_debug("✅ Detectado: staff_ids (legacy)");
        $usuario_ids = array_values(array_unique(array_filter(array_map('intval', $data['staff_ids']))));
    } else {
        log_debug("ℹ️ Sin IDs → Limpiar asignaciones");
        $usuario_ids = [];
    }

    log_debug("📋 IDs a asignar: " . json_encode($usuario_ids));

    // ✅ PASO 7: Obtener responsable_id (NUEVO)
    $responsable_id = isset($data['responsable_id']) ? intval($data['responsable_id']) : null;
    log_debug("👤 Responsable ID: " . ($responsable_id ? $responsable_id : 'null'));

    // Validar que el responsable sea uno de los asignados (si se proporciona)
    if ($responsable_id && !in_array($responsable_id, $usuario_ids)) {
        log_debug("⚠️ Responsable no está en usuario_ids, lo agregaremos");
        // No lo agregamos automáticamente, pero lo permitimos
    }

    // PASO 8: Transacción
    log_debug("🔄 Iniciando transacción...");
    $conn->begin_transaction();

    // ⚠️ IMPORTANTE: Desactivar verificación de claves foráneas temporalmente
    // Esto permite insertar IDs de 'usuarios' en la columna 'staff_id' de 'servicio_staff'
    // aunque no existan en la tabla 'staff' (debido a la migración de lógica).
    $conn->query("SET FOREIGN_KEY_CHECKS=0");

    try {
        // ✅ PASO 8.5: Obtener ID de Operación Maestra para este servicio
        log_debug("🏗️ Buscando Operación Maestra para el servicio $servicio_id...");
        // También traemos el actividad_id del servicio por si hay que crear la maestra
        $stmtMaster = $conn->prepare("
            SELECT o.id, s.actividad_id 
            FROM servicios s
            LEFT JOIN operaciones o ON o.servicio_id = s.id AND o.is_master = 1
            WHERE s.id = ? 
            LIMIT 1
        ");
        $stmtMaster->bind_param("i", $servicio_id);
        $stmtMaster->execute();
        $resMaster = $stmtMaster->get_result();

        $master_operacion_id = null;
        $actividad_id_servicio = null;

        if ($rowMaster = $resMaster->fetch_assoc()) {
            $master_operacion_id = $rowMaster['id'] ? (int) $rowMaster['id'] : null;
            $actividad_id_servicio = $rowMaster['actividad_id'] ? (int) $rowMaster['actividad_id'] : null;

            if ($master_operacion_id) {
                log_debug("   ✅ ID Maestro encontrado: $master_operacion_id");
            }
        }

        if (!$master_operacion_id) {
            // Fallback: Crear una si no existe (por si falla la migración o creación inicial)
            log_debug("   ⚠️ No se encontró Operación Maestra, creando una de emergencia...");
            $desc_e = "Alistamiento/General (Maestra)";
            $stmtM2 = $conn->prepare("INSERT INTO operaciones (servicio_id, actividad_estandar_id, descripcion, fecha_inicio, is_master) VALUES (?, ?, ?, NOW(), 1)");
            $stmtM2->bind_param("iis", $servicio_id, $actividad_id_servicio, $desc_e);
            $stmtM2->execute();
            $master_operacion_id = $conn->insert_id;
            $stmtM2->close();
            log_debug("   ✅ Operación Maestra de emergencia creada: $master_operacion_id (Actividad: " . ($actividad_id_servicio ?? 'NULL') . ")");
        }
        $stmtMaster->close();

        // ✅ PASO 8.6: Determinar si el borrado es selectivo por operación
        $target_operacion_id = (isset($data['operacion_id']) && $data['operacion_id'] !== null) ? (int) $data['operacion_id'] : null;

        // Eliminar asignaciones previas
        if ($target_operacion_id) {
            log_debug("🗑️ Eliminando asignaciones previas SOLO para la operación $target_operacion_id");
            $sqlDelete = "DELETE FROM servicio_staff WHERE servicio_id = ? AND operacion_id = ?";
            $stmtDelete = $conn->prepare($sqlDelete);
            $stmtDelete->bind_param("ii", $servicio_id, $target_operacion_id);
        } else {
            log_debug("🗑️ Eliminando TODAS las asignaciones previas del servicio (Modo Global)");
            $sqlDelete = "DELETE FROM servicio_staff WHERE servicio_id = ?";
            $stmtDelete = $conn->prepare($sqlDelete);
            $stmtDelete->bind_param("i", $servicio_id);
        }

        $stmtDelete->execute();
        $deletedCount = $stmtDelete->affected_rows;
        log_debug("   ✅ Eliminadas $deletedCount asignaciones");
        $stmtDelete->close();

        // 📋 PASO 8.6: Procesar Asignaciones
        $assignments_to_insert = [];

        if (isset($data['assignments']) && is_array($data['assignments'])) {
            log_debug("🧩 Procesando listado de 'assignments' detallado...");
            foreach ($data['assignments'] as $assign) {
                $u_id = isset($assign['usuario_id']) ? (int) $assign['usuario_id'] : (isset($assign['id']) ? (int) $assign['id'] : null);
                $o_id = (isset($assign['operacion_id']) && $assign['operacion_id'] !== null) ? (int) $assign['operacion_id'] : $master_operacion_id;

                if ($u_id) {
                    if ($target_operacion_id === null || $o_id === $target_operacion_id) {
                        $assignments_to_insert[] = ['u' => $u_id, 'o' => $o_id];
                    }
                }
            }
        } elseif (!empty($usuario_ids)) {
            log_debug("📋 Procesando 'usuario_ids' legacy (Modo Simple)...");
            foreach ($usuario_ids as $u_id) {
                $assignments_to_insert[] = ['u' => $u_id, 'o' => $master_operacion_id];
            }
        }

        // Insertar nuevas con asignado_por
        if (!empty($assignments_to_insert)) {
            log_debug("✅ Insertando " . count($assignments_to_insert) . " nuevas asignaciones");

            // INSERT con asignado_por y operacion_id
            $sqlInsert = "INSERT INTO servicio_staff (servicio_id, staff_id, operacion_id, asignado_por) VALUES (?, ?, ?, ?)";
            $stmtInsert = $conn->prepare($sqlInsert);

            if (!$stmtInsert) {
                throw new Exception('Error en inserción: ' . $conn->error);
            }

            $asignado_por = $currentUser['id'];
            $insertCount = 0;

            foreach ($assignments_to_insert as $item) {
                $u_id = $item['u'];
                $o_id = $item['o'];
                $stmtInsert->bind_param("iiii", $servicio_id, $u_id, $o_id, $asignado_por);
                if (!$stmtInsert->execute()) {
                    throw new Exception("Error asignando usuario $u_id a operacion $o_id: " . $stmtInsert->error);
                }
                $insertCount++;
            }
            log_debug("   ✅ Insertadas $insertCount asignaciones vinculadas a operaciones");
            $stmtInsert->close();
        } else {
            log_debug("ℹ️ Sin asignaciones a insertar");
        }

        // ✅ PASO 9: Actualizar responsable_id en servicios (NUEVO)
        if ($responsable_id) {
            log_debug("👤 Actualizando responsable_id en servicios...");

            $sqlUpdateResponsable = "UPDATE servicios SET responsable_id = ? WHERE id = ?";
            $stmtUpdateResponsable = $conn->prepare($sqlUpdateResponsable);

            if (!$stmtUpdateResponsable) {
                throw new Exception('Error actualizando responsable: ' . $conn->error);
            }

            $stmtUpdateResponsable->bind_param("ii", $responsable_id, $servicio_id);

            if (!$stmtUpdateResponsable->execute()) {
                throw new Exception('Error al actualizar responsable: ' . $stmtUpdateResponsable->error);
            }

            log_debug("   ✅ responsable_id actualizado a $responsable_id");
            $stmtUpdateResponsable->close();
        } else {
            log_debug("ℹ️ Sin responsable_id para actualizar");
        }

        // ✅ PASO 9.5: Actualizar flag 'personal_confirmado' y disparar Workflow automático
        $stmtCount = $conn->prepare("SELECT COUNT(*) as total FROM servicio_staff WHERE servicio_id = ?");
        $stmtCount->bind_param("i", $servicio_id);
        $stmtCount->execute();
        $rowCount = $stmtCount->get_result()->fetch_assoc();
        $stmtCount->close();
        $total_real = (int) ($rowCount['total'] ?? 0);

        $personal_valor = ($total_real > 0) ? 1 : 0;
        log_debug("🔄 Actualizando flag personal_confirmado a $personal_valor (total staff en BD: $total_real)...");
        $sqlUpdateFlag = "UPDATE servicios SET personal_confirmado = ? WHERE id = ?";
        $stmtFlag = $conn->prepare($sqlUpdateFlag);
        $stmtFlag->bind_param("ii", $personal_valor, $servicio_id);
        $stmtFlag->execute();
        $stmtFlag->close();

        // Restaurar verificación de claves foráneas
        $conn->query("SET FOREIGN_KEY_CHECKS=1");

        $conn->commit();
        log_debug("✅ Transacción confirmada");

        // ✅ DISPARAR WORKFLOW AUTOMÁTICO (si hay personal confirmado)
        if ($personal_valor === 1) {
            require_once __DIR__ . '/../../workflow/workflow_helper.php';
            log_debug("⚡ Disparando WorkflowHelper::evaluarTriggersAutomaticos para servicio #$servicio_id...");
            WorkflowHelper::evaluarTriggersAutomaticos($conn, $servicio_id, $currentUser['id']);
        }
    } catch (Exception $e) {
        log_debug("❌ Error en transacción: " . $e->getMessage());
        $conn->rollback();
        // Restaurar verificación en caso de error también
        $conn->query("SET FOREIGN_KEY_CHECKS=1");
        throw $e;
    }

    // PASO 10: Obtener usuarios asignados
    log_debug("📋 Cargando personal asignado...");

    $sqlSelect = "
        SELECT 
            u.id as usuario_id,
            u.NOMBRE_USER as nombre,
            u.NOMBRE_CLIENTE as apellido,
            u.CORREO as correo,
            u.TELEFONO as telefono,
            u.URL_FOTO as foto,
            CASE WHEN u.ESTADO_USER = 'activo' THEN 1 ELSE 0 END as activo,
            u.CODIGO_STAFF as codigo_staff,
            u.ID_POSICION as posicion_id,
            u.ID_DEPARTAMENTO as departamento_id,
            ss.id as pivot_id,
            ss.asignado_por,
            ss.created_at,
            ss.operacion_id,
            o.descripcion as operacion_nombre
        FROM servicio_staff ss
        INNER JOIN usuarios u ON ss.staff_id = u.id
        LEFT JOIN operaciones o ON ss.operacion_id = o.id
        WHERE ss.servicio_id = ?
        ORDER BY u.NOMBRE_USER ASC, o.id ASC
    ";

    $stmtSelect = $conn->prepare($sqlSelect);
    if (!$stmtSelect) {
        throw new Exception('Error en select: ' . $conn->error);
    }

    $stmtSelect->bind_param("i", $servicio_id);
    $stmtSelect->execute();
    $resultSelect = $stmtSelect->get_result();

    $usuarios_asignados = [];
    while ($row = $resultSelect->fetch_assoc()) {
        $usuarios_asignados[] = [
            'usuario_id' => intval($row['usuario_id']),
            'nombre' => $row['nombre'] ?? '',
            'apellido' => $row['apellido'] ?? '',
            'correo' => $row['correo'] ?? '',
            'telefono' => $row['telefono'],
            'foto' => $row['foto'],
            'activo' => boolval($row['activo']),
            'codigo_staff' => $row['codigo_staff'],
            'posicion_id' => $row['posicion_id'],
            'departamento_id' => $row['departamento_id'],
            'servicio_id' => $servicio_id,
            'asignado_por' => intval($row['asignado_por']),
            'asignado_en' => $row['created_at'],
            'operacion_id' => isset($row['operacion_id']) ? intval($row['operacion_id']) : null,
            'operacion_nombre' => $row['operacion_nombre'] ?? null
        ];
    }
    $stmtSelect->close();

    log_debug("✅ " . count($usuarios_asignados) . " usuarios cargados");

    // PASO 11: Respuesta
    $response = [
        'success' => true,
        'message' => 'Personal y responsable del servicio actualizado exitosamente',
        'data' => [
            'servicio_id' => $servicio_id,
            'responsable_id' => $responsable_id,
            'usuarios_asignados' => $usuarios_asignados,
            'total_asignados' => count($usuarios_asignados)
        ],
        'actualizado_por' => $currentUser['usuario'],
        'actualizado_por_id' => $currentUser['id']
    ];

    log_debug("📤 Respuesta enviada con " . count($usuarios_asignados) . " usuarios y responsable_id=$responsable_id");
    log_debug("========================================\n");

    sendJsonResponse($response);
} catch (Exception $e) {
    log_debug("🔴 Exception: " . $e->getMessage());
    log_debug("========================================\n");
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}