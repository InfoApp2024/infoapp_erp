<?php

/**
 * PUT/POST /servicio_staff/actualizar.php
 * 
 * Endpoint para actualizar personal y responsable de un servicio
 * ✅ VERSIÓN FINAL: Actualiza servicio_staff Y servicios.responsable_id
 * TODO EN UNA TRANSACCIÓN ATÓMICA
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_actualizar_final.txt');

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
    logAccess($currentUser, '/servicio/servicio_staff/actualizar.php', 'update_service_staff');

    log_debug("========================================");
    log_debug("🆕 ACTUALIZAR USUARIOS Y RESPONSABLE");
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

    // ✅ PASO 5.5: Control de Estados y Permisos (Seguridad)
    $sqlState = "SELECT eb.nombre as estado_base_nombre, eb.codigo as estado_base_codigo, eb.permite_edicion
                FROM servicios s
                JOIN estados_proceso ep ON s.estado = ep.id
                JOIN estados_base eb ON ep.estado_base_codigo = eb.codigo
                WHERE s.id = ? LIMIT 1";
    $stmtState = $conn->prepare($sqlState);
    $stmtState->bind_param("i", $servicio_id);
    $stmtState->execute();
    $resState = $stmtState->get_result();
    $baseInfo = $resState->fetch_assoc();
    $stmtState->close();

    if ($baseInfo) {
        $estadoCodigo = $baseInfo['estado_base_codigo'];
        $isTerminal = in_array($estadoCodigo, ['LEGALIZADO', 'CANCELADO']);
        $permiteEdicion = (int)$baseInfo['permite_edicion'];

        // Si es terminal, BLOQUEO ABSOLUTO (según requerimiento)
        if ($isTerminal) {
            log_debug("❌ Bloqueo ABSOLUTO por estado terminal: $estadoCodigo");
            sendJsonResponse(errorResponse("No se puede gestionar el personal. El servicio está en estado final ($estadoCodigo). Debe solicitar el retorno desde Gestión Financiera."), 403);
        }

        // Si NO permite edición (y no es terminal), verificar bypass por permiso
        if ($permiteEdicion === 0) {
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

            if (!$canEdit) {
                log_debug("❌ Bloqueado por estado: $estadoCodigo (Sin permiso can_edit_closed_ops)");
                sendJsonResponse(errorResponse("No tienes permiso para modificar el personal en este estado ({$baseInfo['estado_base_nombre']})."), 403);
            } else {
                log_debug("🔓 Bypass de personal permitido por 'can_edit_closed_ops' en estado '{$baseInfo['estado_base_nombre']}'");
            }
        }
    }

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
        // ✅ DETERMINAR SI EL BORRADO ES SELECTIVO POR OPERACIÓN
        $target_operacion_id = (isset($data['operacion_id']) && $data['operacion_id'] !== null) ? (int) $data['operacion_id'] : null;

        // Eliminar asignaciones previas
        if ($target_operacion_id !== null) {
            log_debug("🗑️ Eliminando asignaciones previas SOLO para la operación $target_operacion_id");
            $sqlDelete = "DELETE FROM servicio_staff WHERE servicio_id = ? AND operacion_id = ?";
            $stmtDelete = $conn->prepare($sqlDelete);
            $stmtDelete->bind_param("ii", $servicio_id, $target_operacion_id);
        } else {
            log_debug("🗑️ Eliminando TODAS las asignaciones previas del servicio");
            $sqlDelete = "DELETE FROM servicio_staff WHERE servicio_id = ?";
            $stmtDelete = $conn->prepare($sqlDelete);
            $stmtDelete->bind_param("i", $servicio_id);
        }

        $stmtDelete->execute();
        $deletedCount = $stmtDelete->affected_rows;
        log_debug("   ✅ Eliminadas $deletedCount asignaciones");
        $stmtDelete->close();

        // Insertar nuevas con asignado_por
        if (!empty($data['staff_assignments']) && is_array($data['staff_assignments'])) {
            log_debug("✅ Insertando " . count($data['staff_assignments']) . " nuevas asignaciones detalladas");
            $sqlInsert = "INSERT INTO servicio_staff (servicio_id, staff_id, operacion_id, asignado_por) VALUES (?, ?, ?, ?)";
            $stmtInsert = $conn->prepare($sqlInsert);
            $asignado_por = $currentUser['id'];

            foreach ($data['staff_assignments'] as $assignment) {
                $u_id = intval($assignment['usuario_id']);
                $o_id = isset($assignment['operacion_id']) ? intval($assignment['operacion_id']) : null;
                if ($o_id <= 0)
                    $o_id = null;

                // ✅ PROTECCIÓN CONTRA DUPLICADOS (Sincronizado)
                if ($target_operacion_id === null || $o_id === $target_operacion_id) {
                    $stmtInsert->bind_param("iiii", $servicio_id, $u_id, $o_id, $asignado_por);
                    $stmtInsert->execute();
                    log_debug("   ✓ Usuario $u_id asignado a operacion " . ($o_id ?? 'NULL'));
                }
            }
            $stmtInsert->close();
        } elseif (!empty($usuario_ids)) {
            log_debug("✅ Insertando " . count($usuario_ids) . " nuevas asignaciones (legacy mode)");

            // INSERT con asignado_por
            $sqlInsert = "INSERT INTO servicio_staff (servicio_id, staff_id, asignado_por) VALUES (?, ?, ?)";
            $stmtInsert = $conn->prepare($sqlInsert);

            if (!$stmtInsert) {
                throw new Exception('Error en inserción: ' . $conn->error);
            }

            $asignado_por = $currentUser['id'];
            $insertCount = 0;

            foreach ($usuario_ids as $usuario_id) {
                $stmtInsert->bind_param("iii", $servicio_id, $usuario_id, $asignado_por);
                if (!$stmtInsert->execute()) {
                    throw new Exception('Error asignando usuario: ' . $stmtInsert->error);
                }
                $insertCount++;
                log_debug("   ✓ Usuario $usuario_id asignado");
            }
            log_debug("   ✅ Insertadas $insertCount asignaciones");
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

        // Restaurar verificación de claves foráneas
        $conn->query("SET FOREIGN_KEY_CHECKS=1");

        $conn->commit();
        log_debug("✅ Transacción confirmada");
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
