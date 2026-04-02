<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio_repuestos/eliminar_repuesto_servicio.php', 'delete_service_inventory');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Obtener y validar datos JSON
    $input = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        sendJsonResponse(errorResponse('JSON inválido'), 400);
    }

    // PASO 5: Validar campos requeridos
    if (!isset($input['servicio_repuesto_id']) || empty($input['servicio_repuesto_id'])) {
        sendJsonResponse(errorResponse('Campo requerido: servicio_repuesto_id'), 400);
    }

    $servicioRepuestoId = (int) $input['servicio_repuesto_id'];
    $devolverStock = isset($input['devolver_stock']) ? filter_var($input['devolver_stock'], FILTER_VALIDATE_BOOLEAN) : true;
    $razon = $input['razon'] ?? null;
    $usuarioElimina = $input['usuario_elimina'] ?? $currentUser['id'];

    if ($servicioRepuestoId <= 0) {
        sendJsonResponse(errorResponse('ID de servicio_repuesto inválido'), 400);
    }

    // PASO 6: Conexión a BD
    require '../conexion.php';

    // PASO 7: Iniciar transacción
    $conn->autocommit(false);

    try {
        // PASO 8: Verificar que la relación servicio-repuesto existe
        $stmtCheck = $conn->prepare("
            SELECT 
                sr.id,
                sr.servicio_id,
                sr.inventory_item_id,
                sr.cantidad,
                sr.costo_unitario,
                sr.fecha_asignacion,
                i.sku as item_sku,
                i.name as item_nombre,
                i.current_stock as item_stock_actual,
                s.o_servicio,
                s.anular_servicio,
                s.estado as servicio_estado
            FROM servicio_repuestos sr
            INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
            INNER JOIN servicios s ON sr.servicio_id = s.id
            WHERE sr.id = ?
        ");
        $stmtCheck->bind_param("i", $servicioRepuestoId);
        $stmtCheck->execute();
        $result = $stmtCheck->get_result();

        if ($result->num_rows === 0) {
            throw new Exception("Relación servicio-repuesto no encontrada");
        }

        $relacion = $result->fetch_assoc();

        // PASO 9: Validaciones de negocio
        if ((int) $relacion['anular_servicio'] === 1) {
            throw new Exception("No se pueden eliminar repuestos de un servicio anulado");
        }

        // ? VERIFICAR ESTADO DEL SERVICIO PARA BLOQUEO DE EDICIÓN
        $sqlState = "SELECT sb.permite_edicion, sb.codigo as estado_base_codigo, sb.nombre as estado_base_nombre
                    FROM servicios s
                    INNER JOIN estados_proceso ep ON s.estado = ep.id
                    INNER JOIN estados_base sb ON ep.estado_base_codigo = sb.codigo
                    WHERE s.id = ? 
                    LIMIT 1";
        $stmtState = $conn->prepare($sqlState);
        $stmtState->bind_param("i", $relacion['servicio_id']);
        $stmtState->execute();
        $resState = $stmtState->get_result();
        
        if ($rowState = $resState->fetch_assoc()) {
            $estadoCodigo = $rowState['estado_base_codigo'];
            $isTerminal = in_array($estadoCodigo, ['LEGALIZADO', 'CANCELADO']);
            $permiteEdicion = (int)$rowState['permite_edicion'];

            // Si es terminal, BLOQUEO ABSOLUTO
            if ($isTerminal) {
                log_debug("❌ Bloqueo ABSOLUTO por estado terminal: $estadoCodigo");
                sendJsonResponse(errorResponse("No se puede eliminar el repuesto. El servicio está en estado final ($estadoCodigo). Debe solicitar el retorno desde Gestión Financiera."), 403);
            }

            // Si NO permite edición (y no es terminal), verificar bypass
            if ($permiteEdicion === 0) {
                // Verificar bypass
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
                    throw new Exception("No tienes permiso para eliminar el repuesto en este estado ({$rowState['estado_base_nombre']}).");
                }
            }
        }
        $stmtState->close();

        // Preparar datos para logs y respuesta
        $servicioId = (int) $relacion['servicio_id'];
        $itemId = (int) $relacion['inventory_item_id'];
        $cantidadDevolver = (float) $relacion['cantidad'];
        $costoUnitario = (float) $relacion['costo_unitario'];
        $stockActual = (float) $relacion['item_stock_actual'];
        $numeroServicio = $relacion['o_servicio'];
        $itemNombre = $relacion['item_nombre'];
        $itemSku = $relacion['item_sku'];

        // PASO 10: Eliminar la relación servicio-repuesto
        $stmtDelete = $conn->prepare("DELETE FROM servicio_repuestos WHERE id = ?");
        $stmtDelete->bind_param("i", $servicioRepuestoId);

        if (!$stmtDelete->execute()) {
            throw new Exception("Error eliminando la asignación: " . $stmtDelete->error);
        }

        if ($stmtDelete->affected_rows === 0) {
            throw new Exception("No se pudo eliminar la asignación (no encontrada)");
        }

        $stockFinal = $stockActual;

        // PASO 11: Devolver stock si se solicita
        if ($devolverStock) {
            $stmtUpdateStock = $conn->prepare("
                UPDATE inventory_items 
                SET current_stock = current_stock + ?,
                    updated_at = NOW()
                WHERE id = ?
            ");
            $stmtUpdateStock->bind_param("di", $cantidadDevolver, $itemId);

            if (!$stmtUpdateStock->execute()) {
                throw new Exception("Error devolviendo stock al inventario: " . $stmtUpdateStock->error);
            }

            $stockFinal = $stockActual + $cantidadDevolver;

            // PASO 12: Crear movimiento de entrada en inventario
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
                ) VALUES (?, 'entrada', 'devolucion', ?, ?, ?, ?, 'service', ?, ?, ?, NOW())
            ");

            $movementNotes = "Devuelto del servicio #$numeroServicio";
            if (!empty($razon)) {
                $movementNotes .= " - Razón: $razon";
            }

            // i: itemId
            // d: cantidadDevolver (double)
            // d: stockActual (double)
            // d: stockFinal (double)
            // d: costoUnitario
            // i: servicioId
            // s: movementNotes
            // i: usuarioElimina
            $stmtMovement->bind_param("iddddisi", $itemId, $cantidadDevolver, $stockActual, $stockFinal, $costoUnitario, $servicioId, $movementNotes, $usuarioElimina);
            $stmtMovement->execute(); // No es crítico si falla
        }

        // PASO 13: Verificar si el servicio sigue teniendo repuestos
        $stmtCheckRemaining = $conn->prepare("
            SELECT COUNT(*) as total_repuestos 
            FROM servicio_repuestos 
            WHERE servicio_id = ?
        ");
        $stmtCheckRemaining->bind_param("i", $servicioId);
        $stmtCheckRemaining->execute();
        $remainingResult = $stmtCheckRemaining->get_result();
        $totalRepuestos = (int) $remainingResult->fetch_assoc()['total_repuestos'];

        // PASO 14: Actualizar flag del servicio si ya no tiene repuestos
        if ($totalRepuestos === 0) {
            $stmtUpdateService = $conn->prepare("
                UPDATE servicios 
                SET suministraron_repuestos = 0 
                WHERE id = ?
            ");
            $stmtUpdateService->bind_param("i", $servicioId);
            $stmtUpdateService->execute();
        }

        // PASO 15: Log de auditoría (opcional)
        try {
            $stmtAudit = $conn->prepare("
                INSERT INTO audit_log (
                    tabla, 
                    operacion, 
                    registro_id, 
                    datos_anteriores, 
                    usuario_id, 
                    fecha_operacion
                ) VALUES (?, 'DELETE', ?, ?, ?, NOW())
            ");

            $datosAnteriores = json_encode([
                'servicio_id' => $servicioId,
                'inventory_item_id' => $itemId,
                'cantidad' => $cantidadDevolver,
                'costo_unitario' => $costoUnitario,
                'item_nombre' => $itemNombre,
                'item_sku' => $itemSku,
                'razon_eliminacion' => $razon
            ]);

            $tabla = 'servicio_repuestos';
            $stmtAudit->bind_param("sisi", $tabla, $servicioRepuestoId, $datosAnteriores, $usuarioElimina);
            $stmtAudit->execute();
        } catch (Exception $auditError) {
            // Log el error de auditoría pero no fallar la operación principal
            error_log("Warning: No se pudo crear log de auditoría: " . $auditError->getMessage());
        }

        // COMMIT de la transacción
        $conn->commit();

        // PASO 16: Preparar respuesta exitosa
        $response = [
            'success' => true,
            'data' => [
                'eliminado' => true,
                'servicio_repuesto_id' => $servicioRepuestoId,
                'servicio_id' => $servicioId,
                'numero_servicio' => $numeroServicio,
                'item_eliminado' => [
                    'id' => $itemId,
                    'sku' => $itemSku,
                    'nombre' => $itemNombre,
                    'cantidad_eliminada' => $cantidadDevolver,
                    'costo_unitario' => $costoUnitario,
                    'valor_total_eliminado' => round($cantidadDevolver * $costoUnitario, 2)
                ],
                'stock_info' => [
                    'stock_devuelto' => $devolverStock,
                    'cantidad_devuelta' => $devolverStock ? $cantidadDevolver : 0,
                    'stock_anterior' => $stockActual,
                    'stock_actual' => $stockFinal
                ],
                'servicio_info' => [
                    'repuestos_restantes' => $totalRepuestos,
                    'tiene_repuestos' => $totalRepuestos > 0,
                    'flag_actualizado' => $totalRepuestos === 0
                ]
            ],
            'message' => "Repuesto '$itemNombre' eliminado del servicio #$numeroServicio" .
                ($devolverStock ? " y $cantidadDevolver unidades devueltas al stock" : ""),
            'processed_by' => $currentUser['usuario'],
            'user_role' => $currentUser['rol']
        ];

        // Agregar razón si se proporcionó
        if (!empty($razon)) {
            $response['data']['razon'] = $razon;
        }

        sendJsonResponse($response);
    } catch (Exception $e) {
        // ROLLBACK en caso de error
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    error_log("Error en eliminar_repuesto_servicio.php: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error eliminando repuesto del servicio: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->autocommit(true); // Restaurar autocommit
    $conn->close();
}
