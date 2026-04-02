<?php
// ============================================
// CONFIGURACIÓN DE DEBUG Y ERROR REPORTING
// ============================================
error_reporting(E_ALL);
ini_set('display_errors', 0);  // NO mostrar errores en pantalla
ini_set('log_errors', 1);

// Configurar ubicación del log
$logFile = __DIR__ . '/asignar_repuestos.log';
ini_set('error_log', $logFile);

// Limpiar cualquier salida previa
while (ob_get_level()) {
    ob_end_clean();
}
ob_start();

// Función de log
function logDebug($message, $data = null)
{
    $timestamp = date('Y-m-d H:i:s');
    $logMessage = "[$timestamp] $message";
    if ($data !== null) {
        $logMessage .= " | Data: " . json_encode($data, JSON_UNESCAPED_UNICODE | JSON_PARTIAL_OUTPUT_ON_ERROR);
    }
    $logMessage .= "\n";

    // Escribir al archivo de log
    global $logFile;
    if (isset($logFile)) {
        @file_put_contents($logFile, $logMessage, FILE_APPEND);
    }
    error_log($logMessage);
}

logDebug("========== INICIO SCRIPT asignar_repuestos_servicio.php ==========");

// ============================================
// VERIFICACIÓN DE DEPENDENCIAS
// ============================================
if (!file_exists('../login/auth_middleware.php')) {
    logDebug("ERROR: auth_middleware.php no encontrado");
    while (ob_get_level())
        ob_end_clean();
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode(['success' => false, 'message' => 'auth_middleware.php no encontrado']);
    exit;
}

require_once '../login/auth_middleware.php';
require_once '../workflow/workflow_helper.php';
logDebug("auth_middleware.php y workflow_helper.php cargados");

// Verificar funciones críticas
$requiredFunctions = ['requireAuth', 'sendJsonResponse', 'errorResponse'];
foreach ($requiredFunctions as $func) {
    if (!function_exists($func)) {
        logDebug("ERROR: Función $func no disponible");
        while (ob_get_level())
            ob_end_clean();
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['success' => false, 'message' => "Función $func no disponible"]);
        exit;
    }
}
logDebug("Funciones requeridas verificadas");

try {
    // ============================================
    // AUTENTICACIÓN
    // ============================================
    logDebug("Iniciando autenticación");
    $currentUser = requireAuth();
    logDebug("Usuario autenticado", [
        'id' => $currentUser['id'] ?? null,
        'usuario' => $currentUser['usuario'] ?? null,
        'rol' => $currentUser['rol'] ?? null
    ]);

    if (function_exists('logAccess')) {
        logAccess($currentUser, '/servicio/asignar_repuestos_servicio.php', 'assign_inventory');
    }

    // ============================================
    // VALIDACIÓN DE MÉTODO HTTP
    // ============================================
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        logDebug("ERROR: Método no permitido", $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // ============================================
    // LECTURA Y VALIDACIÓN DE JSON
    // ============================================
    $rawInput = file_get_contents('php://input');
    logDebug("Input recibido", ['length' => strlen($rawInput)]);

    $input = json_decode($rawInput, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        logDebug("ERROR: JSON inválido", ['error' => json_last_error_msg()]);
        sendJsonResponse(errorResponse('JSON inválido: ' . json_last_error_msg()), 400);
    }

    logDebug("JSON decodificado", $input);

    // ============================================
    // VALIDACIÓN DE CAMPOS REQUERIDOS
    // ============================================
    if (!isset($input['servicio_id']) || !isset($input['repuestos']) || !is_array($input['repuestos'])) {
        logDebug("ERROR: Campos requeridos faltantes");
        sendJsonResponse(errorResponse('Campos requeridos: servicio_id, repuestos (array)'), 400);
    }

    $servicioId = (int) $input['servicio_id'];
    $repuestos = $input['repuestos'];
    $observaciones = $input['observaciones'] ?? null;

    // 🔧 CORRECCIÓN: Usar 'id' en lugar de 'usuario_id'
    $usuarioAsigno = $input['usuario_asigno'] ?? ($currentUser['id'] ?? null);

    logDebug("Variables extraídas", [
        'servicio_id' => $servicioId,
        'cantidad_repuestos' => count($repuestos),
        'usuario_asigno' => $usuarioAsigno
    ]);

    // Validaciones básicas
    if ($servicioId <= 0) {
        logDebug("ERROR: ID de servicio inválido", $servicioId);
        sendJsonResponse(errorResponse('ID de servicio inválido'), 400);
    }

    if (empty($repuestos)) {
        logDebug("ERROR: Array de repuestos vacío");
        sendJsonResponse(errorResponse('Debe especificar al menos un repuesto'), 400);
    }

    if (!$usuarioAsigno) {
        logDebug("ERROR: No se pudo determinar usuario_asigno");
        sendJsonResponse(errorResponse('No se pudo determinar el usuario que asigna'), 400);
    }

    // ============================================
    // VALIDACIÓN DE ESTRUCTURA DE REPUESTOS
    // ============================================
    foreach ($repuestos as $index => $repuesto) {
        if (!isset($repuesto['inventory_item_id']) || !isset($repuesto['cantidad'])) {
            logDebug("ERROR: Repuesto #$index con campos faltantes");
            sendJsonResponse(errorResponse("Repuesto #$index: campos requeridos inventory_item_id, cantidad"), 400);
        }

        $itemId = (int) $repuesto['inventory_item_id'];
        $cantidad = (float) $repuesto['cantidad'];

        if ($itemId <= 0 || $cantidad <= 0) {
            logDebug("ERROR: Repuesto #$index con valores inválidos");
            sendJsonResponse(errorResponse("Repuesto #$index: valores inválidos"), 400);
        }
    }

    logDebug("Validaciones completadas");

    // ============================================
    // CONEXIÓN A BASE DE DATOS
    // ============================================
    if (!file_exists('../conexion.php')) {
        throw new Exception("conexion.php no encontrado");
    }

    require '../conexion.php';

    if (!isset($conn) || !$conn) {
        throw new Exception("Conexión a BD falló");
    }

    logDebug("Conexión a BD establecida");

    // ============================================
    // INICIO DE TRANSACCIÓN
    // ============================================
    $conn->autocommit(false);
    logDebug("Transacción iniciada");

    try {
        // ✅ PASO 8.5: Obtener ID de Operación Maestra para este servicio
        logDebug("Buscando Operación Maestra para el servicio", ['servicio_id' => $servicioId]);
        $stmtMaster = $conn->prepare("SELECT id FROM operaciones WHERE servicio_id = ? AND is_master = 1 LIMIT 1");
        $stmtMaster->bind_param("i", $servicioId);
        $stmtMaster->execute();
        $resMaster = $stmtMaster->get_result();
        $masterOperacionId = null;
        if ($rowMaster = $resMaster->fetch_assoc()) {
            $masterOperacionId = (int) $rowMaster['id'];
            logDebug("ID Maestro encontrado", ['id' => $masterOperacionId]);
        } else {
            // Fallback: Crear si no existe (Seguridad)
            logDebug("No se encontró Operación Maestra, creando de emergencia");
            $desc_e = "Alistamiento/General (Maestra)";
            $stmtM2 = $conn->prepare("INSERT INTO operaciones (servicio_id, descripcion, fecha_inicio, is_master) VALUES (?, ?, NOW(), 1)");
            $stmtM2->bind_param("is", $servicioId, $desc_e);
            $stmtM2->execute();
            $masterOperacionId = $conn->insert_id;
            $stmtM2->close();
            logDebug("Operación Maestra de emergencia creada", ['id' => $masterOperacionId]);
        }
        $stmtMaster->close();

        // ============================================
        // VERIFICACIÓN DEL SERVICIO
        // ============================================
        logDebug("Verificando servicio", ['servicio_id' => $servicioId]);

        $stmtCheckService = $conn->prepare("
            SELECT id, o_servicio, estado, anular_servicio 
            FROM servicios 
            WHERE id = ?
        ");

        if (!$stmtCheckService) {
            throw new Exception("Error preparando query de servicio: " . $conn->error);
        }

        $stmtCheckService->bind_param("i", $servicioId);

        if (!$stmtCheckService->execute()) {
            throw new Exception("Error ejecutando query de servicio: " . $stmtCheckService->error);
        }

        $serviceResult = $stmtCheckService->get_result();

        if ($serviceResult->num_rows === 0) {
            throw new Exception("Servicio no encontrado");
        }

        $servicio = $serviceResult->fetch_assoc();
        logDebug("Servicio encontrado", $servicio);

        if ((int) $servicio['anular_servicio'] === 1) {
            throw new Exception("No se pueden asignar repuestos a un servicio anulado");
        }

        // 🔧 CANDADO DE ESTADO BASE (Seguridad Integrada)
        // Verificar si el estado actual permite edición según el Kernel (Estados Base)
        $stmtBaseCheck = $conn->prepare("
            SELECT eb.permite_edicion, eb.nombre as estado_base_nombre, eb.codigo as estado_base_codigo
            FROM estados_proceso ep
            JOIN estados_base eb ON ep.estado_base_codigo = eb.codigo
            WHERE ep.id = ?
        ");
        $stmtBaseCheck->bind_param("i", $servicio['estado']);
        $stmtBaseCheck->execute();
        $resBase = $stmtBaseCheck->get_result();
        $baseInfo = $resBase->fetch_assoc();
        $stmtBaseCheck->close();

        // Operativos que siempre deben permitir edición en caso de re-apertura
        $estadosOperativos = ['DIAGNOSTICO', 'EN_PROCESO', 'PENDIENTE_REPUESTOS'];
        $esReaperturaOperativa = $baseInfo ? in_array($baseInfo['estado_base_codigo'], $estadosOperativos) : false;

        if ($baseInfo) {
            $estadoCodigo = $baseInfo['estado_base_codigo'];
            $isTerminal = in_array($estadoCodigo, ['LEGALIZADO', 'CANCELADO']);
            $permiteEdicion = (int) $baseInfo['permite_edicion'];

            // Si es terminal, BLOQUEO ABSOLUTO
            if ($isTerminal) {
                logDebug("❌ Bloqueo ABSOLUTO por estado terminal: $estadoCodigo");
                sendJsonResponse(errorResponse("No se puede gestionar los repuestos. El servicio está en estado final ($estadoCodigo). Debe solicitar el retorno desde Gestión Financiera."), 403);
            }

            // Si NO permite edición (y no es terminal), verificar bypass
            if ($permiteEdicion === 0 && !$esReaperturaOperativa) {
                // ? CONSULTA DE SEGURIDAD: Verificar si el usuario tiene permiso de bypass
                $sqlPerm = "SELECT can_edit_closed_ops FROM usuarios WHERE id = ? LIMIT 1";
                $stmtPerm = $conn->prepare($sqlPerm);
                $stmtPerm->bind_param("i", $currentUser['id']);
                $stmtPerm->execute();
                $resPerm = $stmtPerm->get_result();
                $canEdit = false;
                if ($rowPerm = $resPerm->fetch_assoc()) {
                    $canEdit = ((int) $rowPerm['can_edit_closed_ops'] === 1);
                }
                $stmtPerm->close();

                if (!$canEdit) {
                    logDebug("❌ Intento de asignar repuestos bloqueado: Estado '{$baseInfo['estado_base_nombre']}' (Sin permiso bypass)");
                    throw new Exception("No tienes permiso para modificar los repuestos en este estado ({$baseInfo['estado_base_nombre']}).");
                } else {
                    logDebug("🔓 Bypass de asignación de repuestos permitido por 'can_edit_closed_ops' en estado '{$baseInfo['estado_base_nombre']}'");
                }
            }
        }

        // ============================================
        // PASO 9: SINCRONIZACIÓN Y RESTAURACIÓN DE STOCK
        // ============================================
        // Identificar todas las operaciones afectadas en este request para restaurar su stock previo
        $opsAfectadas = [];
        foreach ($repuestos as $r) {
            $opId = (isset($r['operacion_id']) && (int) $r['operacion_id'] > 0)
                ? (int) $r['operacion_id']
                : $masterOperacionId;
            if (!in_array($opId, $opsAfectadas)) {
                $opsAfectadas[] = $opId;
            }
        }

        logDebug("Operaciones afectadas para sincronización", $opsAfectadas);

        foreach ($opsAfectadas as $targetOpId) {
            logDebug("Restaurando stock para operacion_id: $targetOpId");

            // Obtener repuestos actuales de esta operación para devolver stock
            $stmtOld = $conn->prepare("
                SELECT sr.inventory_item_id, sr.cantidad, sr.costo_unitario 
                FROM servicio_repuestos sr
                WHERE sr.servicio_id = ? AND sr.operacion_id = ?
            ");
            $stmtOld->bind_param("ii", $servicioId, $targetOpId);
            $stmtOld->execute();
            $resOld = $stmtOld->get_result();

            while ($old = $resOld->fetch_assoc()) {
                $oItemId = (int) $old['inventory_item_id'];
                $oCant = (float) $old['cantidad'];
                $oCosto = (float) $old['costo_unitario'];

                // 1. Devolver al inventario
                $conn->query("UPDATE inventory_items SET current_stock = current_stock + $oCant WHERE id = $oItemId");

                // 2. Registrar movimiento de retorno por edición
                $notesRet = "Retorno por edición/sincronización - Op #$targetOpId";
                $stmtRet = $conn->prepare("
                    INSERT INTO inventory_movements (
                        inventory_item_id, movement_type, movement_reason, quantity, 
                        previous_stock, new_stock, unit_cost, reference_type, 
                        reference_id, notes, created_by, created_at
                    ) 
                    SELECT ?, 'entrada', 'devolucion', ?, current_stock - ?, current_stock, ?, 'service', ?, ?, ?, NOW()
                    FROM inventory_items WHERE id = ?
                ");
                // previous_stock = current_stock - oCant (porque ya hicimos el UPDATE arriba)
                $stmtRet->bind_param("idddisii", $oItemId, $oCant, $oCant, $oCosto, $servicioId, $notesRet, $usuarioAsigno, $oItemId);
                $stmtRet->execute();
                $stmtRet->close();
            }
            $stmtOld->close();

            // 3. Eliminar registros antiguos de esa operación para re-insertar los nuevos
            $conn->query("DELETE FROM servicio_repuestos WHERE servicio_id = $servicioId AND operacion_id = $targetOpId");
            logDebug("Registros antiguos eliminados para op: $targetOpId");
        }

        // ============================================
        // PROCESAMIENTO DE NUEVOS REPUESTOS (RE-INSERCIÓN)
        // ============================================
        $repuestosAsignados = [];
        $errores = [];
        $totalAsignados = 0;
        $costoTotal = 0.0;

        logDebug("Iniciando procesamiento de repuestos", ['total' => count($repuestos)]);

        foreach ($repuestos as $index => $repuestoData) {
            $itemId = (int) $repuestoData['inventory_item_id'];
            $cantidad = (float) $repuestoData['cantidad'];
            $costoUnitario = isset($repuestoData['costo_unitario']) ? (float) $repuestoData['costo_unitario'] : null;
            $notas = $repuestoData['notas'] ?? null;

            logDebug("Procesando repuesto #$index", [
                'item_id' => $itemId,
                'cantidad' => $cantidad
            ]);

            try {
                // 1. VERIFICAR ITEM EN INVENTARIO
                $stmtCheckItem = $conn->prepare("
                    SELECT id, sku, name, current_stock, unit_cost, is_active 
                    FROM inventory_items 
                    WHERE id = ? AND is_active = 1
                ");

                if (!$stmtCheckItem) {
                    throw new Exception("Error preparando consulta de item: " . $conn->error);
                }

                $stmtCheckItem->bind_param("i", $itemId);

                if (!$stmtCheckItem->execute()) {
                    throw new Exception("Error ejecutando consulta de item: " . $stmtCheckItem->error);
                }

                $itemResult = $stmtCheckItem->get_result();

                if ($itemResult->num_rows === 0) {
                    $errores[] = "Item #$itemId no encontrado o inactivo";
                    logDebug("Item no encontrado", ['item_id' => $itemId]);
                    continue;
                }

                $item = $itemResult->fetch_assoc();
                logDebug("Item encontrado", $item);

                // 2. VERIFICAR STOCK DISPONIBLE
                $stockActual = (float) $item['current_stock'];
                if ($stockActual < $cantidad) {
                    $errores[] = "Item '{$item['name']}' (SKU: {$item['sku']}): stock insuficiente. Disponible: $stockActual, solicitado: $cantidad";
                    logDebug("Stock insuficiente", ['item_id' => $itemId, 'stock' => $stockActual, 'solicitado' => $cantidad]);
                    continue;
                }

                // 3. VERIFICAR SI YA ESTÁ ASIGNADO (Omitido en Sync ya que limpiamos antes)
                /*
                $stmtCheckExisting = $conn->prepare("
                    SELECT id, cantidad 
                    FROM servicio_repuestos 
                    WHERE servicio_id = ? AND inventory_item_id = ?
                ");
                // ... (lógica antigua que causaba el 'secuestro')
                */

                // 4. CALCULAR COSTO FINAL
                // COMPORTAMIENTO CORRECTO: Siempre usar el precio ACTUAL del inventario.
                // Ignoramos el costo_unitario enviado por el cliente ya que puede ser
                // un valor de un ciclo anterior (ej: tras devolución a operaciones).
                // El precio de referencia siempre debe venir de la fuente de verdad: inventory_items.
                $costoFinal = (float) $item['unit_cost'];
                logDebug("Costo calculado", ['costo_final' => $costoFinal, 'fuente' => 'inventory_items.unit_cost']);

                // 5. INSERTAR EN servicio_repuestos
                $stmtInsert = $conn->prepare("
                    INSERT INTO servicio_repuestos (
                        servicio_id, 
                        inventory_item_id, 
                        operacion_id,
                        cantidad, 
                        costo_unitario,
                        notas,
                        usuario_asigno,
                        fecha_asignacion
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())
                ");

                if (!$stmtInsert) {
                    throw new Exception("Error preparando INSERT servicio_repuestos: " . $conn->error);
                }

                $operacionId = (isset($repuestoData['operacion_id']) && (int) $repuestoData['operacion_id'] > 0)
                    ? (int) $repuestoData['operacion_id']
                    : $masterOperacionId;

                $stmtInsert->bind_param("iiiddsi", $servicioId, $itemId, $operacionId, $cantidad, $costoFinal, $notas, $usuarioAsigno);

                if (!$stmtInsert->execute()) {
                    throw new Exception("Error insertando servicio_repuestos: " . $stmtInsert->error);
                }

                $assignmentId = $conn->insert_id;
                logDebug("Repuesto insertado", ['assignment_id' => $assignmentId, 'operacion_id' => $operacionId]);

                // 6. ACTUALIZAR STOCK
                $nuevoStock = $stockActual - $cantidad;

                $stmtUpdateStock = $conn->prepare("
                    UPDATE inventory_items 
                    SET current_stock = current_stock - ?,
                        updated_at = NOW()
                    WHERE id = ?
                ");

                if (!$stmtUpdateStock) {
                    throw new Exception("Error preparando UPDATE stock: " . $conn->error);
                }

                $stmtUpdateStock->bind_param("di", $cantidad, $itemId);

                if (!$stmtUpdateStock->execute()) {
                    throw new Exception("Error actualizando stock: " . $stmtUpdateStock->error);
                }

                logDebug("Stock actualizado", ['nuevo_stock' => $nuevoStock]);

                // 7. 🔧 CREAR MOVIMIENTO EN INVENTARIO (CON VALORES CORRECTOS)
                $movementNotes = "Asignado al servicio #{$servicio['o_servicio']}";

                $stmtMovement = $conn->prepare("
                    INSERT INTO inventory_movements (
                        inventory_item_id,
                        movement_type,
                        movement_reason,
                        quantity,
                        previous_stock,
                        new_stock,
                        unit_cost,
                        reference_type,
                        reference_id,
                        notes,
                        created_by,
                        created_at
                    ) VALUES (?, 'salida', 'uso_servicio', ?, ?, ?, ?, 'service', ?, ?, ?, NOW())
                ");

                if (!$stmtMovement) {
                    logDebug("WARNING: Error preparando INSERT inventory_movements", ['error' => $conn->error]);
                } else {
                    // 🔧 CORRECCIÓN: 8 parámetros con tipos correctos "iddddisi"
                    $stmtMovement->bind_param(
                        "iddddisi",
                        $itemId,           // inventory_item_id (int)
                        $cantidad,         // quantity (double)
                        $stockActual,      // previous_stock (double)
                        $nuevoStock,       // new_stock (double)
                        $costoFinal,       // unit_cost (double)
                        $servicioId,       // reference_id (int)
                        $movementNotes,    // notes (string)
                        $usuarioAsigno     // created_by (int)
                    );

                    if (!$stmtMovement->execute()) {
                        logDebug("WARNING: Error insertando inventory_movements", ['error' => $stmtMovement->error]);
                    } else {
                        $movementId = $conn->insert_id;
                        logDebug("Movimiento creado", ['movement_id' => $movementId]);
                    }
                }

                // 8. AGREGAR A LISTA DE ÉXITOS
                $repuestosAsignados[] = [
                    'id' => $assignmentId,
                    'servicio_id' => $servicioId,
                    'inventory_item_id' => $itemId,
                    'cantidad' => $cantidad,
                    'costo_unitario' => $costoFinal,
                    'costo_total' => $cantidad * $costoFinal,
                    'notas' => $notas,
                    'usuario_asigno' => $usuarioAsigno,
                    'fecha_asignacion' => date('Y-m-d H:i:s'),
                    'item_sku' => $item['sku'],
                    'item_nombre' => $item['name'],
                    'item_stock_anterior' => $stockActual,
                    'item_stock_actual' => $nuevoStock
                ];

                $totalAsignados++;
                $costoTotal += ($cantidad * $costoFinal);

                logDebug("Repuesto procesado exitosamente", ['assignment_id' => $assignmentId]);
            } catch (Exception $e) {
                logDebug("ERROR procesando repuesto #$index", [
                    'item_id' => $itemId,
                    'error' => $e->getMessage()
                ]);
                $errores[] = "Item #$itemId: " . $e->getMessage();
            }
        }

        logDebug("Procesamiento completado", [
            'total_asignados' => $totalAsignados,
            'total_errores' => count($errores)
        ]);

        // ============================================
        // VALIDACIÓN DE RESULTADOS
        // ============================================
        if ($totalAsignados === 0) {
            $errorMsg = "No se pudo asignar ningún repuesto. Errores: " . implode('; ', $errores);
            logDebug("ERROR: " . $errorMsg);
            throw new Exception($errorMsg);
        }

        // ============================================
        // COMMIT DE TRANSACCIÓN
        // ============================================
        $conn->commit();
        logDebug("TRANSACCIÓN CONFIRMADA (COMMIT)");

        // ============================================
        // PREPARAR RESPUESTA EXITOSA
        // ============================================

        // Limpiar output buffer
        while (ob_get_level()) {
            ob_end_clean();
        }

        $response = [
            'success' => true,
            'data' => [
                'repuestos_asignados' => $repuestosAsignados,
                'resumen' => [
                    'total_asignados' => $totalAsignados,
                    'costo_total' => round($costoTotal, 2),
                    'servicio_id' => $servicioId,
                    'servicio_numero' => $servicio['o_servicio'],
                    'errores_count' => count($errores),
                    'procesados' => count($repuestos)
                ],
                'workflow' => $workflow_res // ✅ NUEVO: Informar cambio de estado al frontend
            ],
            'message' => "Se asignaron $totalAsignados repuestos al servicio #{$servicio['o_servicio']} por un valor total de $" . number_format($costoTotal, 2),
            'processed_by' => $currentUser['usuario'] ?? 'unknown',
            'user_role' => $currentUser['rol'] ?? 'unknown'
        ];

        if (!empty($errores)) {
            $response['data']['errores'] = $errores;
            $response['message'] .= ". Algunos items no pudieron procesarse.";
        }

        logDebug("Respuesta exitosa preparada");
        sendJsonResponse($response);
    } catch (Exception $e) {
        // ROLLBACK EN CASO DE ERROR
        $conn->rollback();
        logDebug("ROLLBACK ejecutado");
        throw $e;
    }
} catch (Exception $e) {
    // ============================================
    // MANEJO GLOBAL DE ERRORES
    // ============================================
    logDebug("========== ERROR CRÍTICO ==========", [
        'message' => $e->getMessage(),
        'file' => $e->getFile(),
        'line' => $e->getLine()
    ]);

    // Limpiar output buffer
    while (ob_get_level()) {
        ob_end_clean();
    }

    // Enviar headers
    if (!headers_sent()) {
        header('Content-Type: application/json; charset=utf-8');
        header('HTTP/1.1 500 Internal Server Error');
    }

    $errorResponse = [
        'success' => false,
        'message' => 'Error asignando repuestos: ' . $e->getMessage(),
        'debug' => [
            'exception' => $e->getMessage(),
            'file' => basename($e->getFile()),
            'line' => $e->getLine(),
            'servicio_id' => $servicioId ?? null,
            'user_id' => $currentUser['id'] ?? null,
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ];

    logDebug("Enviando respuesta de error");

    echo json_encode($errorResponse, JSON_UNESCAPED_UNICODE);
    exit;
}

// ============================================
// LIMPIEZA Y CIERRE
// ============================================
if (isset($conn)) {
    $conn->autocommit(true);
    $conn->close();
    logDebug("Conexión cerrada");
}

logDebug("========== FIN SCRIPT ==========");
