<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio_repuestos/actualizar_cantidad_repuesto.php', 'update_service_inventory');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Obtener y validar datos JSON
    $input = json_decode(file_get_contents('php://input'), true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        sendJsonResponse(errorResponse('JSON inválido'), 400);
    }

    // PASO 5: Validar campos requeridos
    if (!isset($input['servicio_repuesto_id']) || !isset($input['nueva_cantidad'])) {
        sendJsonResponse(errorResponse('Campos requeridos: servicio_repuesto_id, nueva_cantidad'), 400);
    }

    $servicioRepuestoId = (int) $input['servicio_repuesto_id'];
    $nuevaCantidad = (float) $input['nueva_cantidad'];
    $notas = $input['notas'] ?? null;
    $usuarioActualiza = $input['usuario_actualiza'] ?? $currentUser['id'];

    // Validar datos
    if ($servicioRepuestoId <= 0) {
        sendJsonResponse(errorResponse('ID de servicio_repuesto inválido'), 400);
    }

    if ($nuevaCantidad <= 0) {
        sendJsonResponse(errorResponse('La nueva cantidad debe ser mayor a 0'), 400);
    }

    // PASO 6: Conexión a BD
    require '../conexion.php';

    // PASO 7: Iniciar transacción
    $conn->autocommit(false);

    try {
        // PASO 8: Obtener datos actuales de la relación
        $stmtGet = $conn->prepare("
            SELECT 
                sr.id,
                sr.servicio_id,
                sr.inventory_item_id,
                sr.cantidad as cantidad_actual,
                sr.costo_unitario,
                sr.fecha_asignacion,
                i.sku as item_sku,
                i.name as item_nombre,
                i.current_stock as item_stock_actual,
                i.minimum_stock as item_stock_minimo,
                s.o_servicio,
                s.anular_servicio
            FROM servicio_repuestos sr
            INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
            INNER JOIN servicios s ON sr.servicio_id = s.id
            WHERE sr.id = ?
        ");
        $stmtGet->bind_param("i", $servicioRepuestoId);
        $stmtGet->execute();
        $result = $stmtGet->get_result();

        if ($result->num_rows === 0) {
            throw new Exception("Relación servicio-repuesto no encontrada");
        }

        $relacion = $result->fetch_assoc();

        // PASO 9: Validaciones de negocio
        if ((int) $relacion['anular_servicio'] === 1) {
            throw new Exception("No se pueden modificar repuestos de un servicio anulado");
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
                logDebug("❌ Bloqueo ABSOLUTO por estado terminal: $estadoCodigo");
                sendJsonResponse(errorResponse("No se puede editar la cantidad. El servicio está en estado final ($estadoCodigo). Debe solicitar el retorno desde Gestión Financiera."), 403);
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
                    throw new Exception("No tienes permiso para modificar la cantidad en este estado ({$rowState['estado_base_nombre']}).");
                }
            }
        }
        $stmtState->close();

        $cantidadActual = (float) $relacion['cantidad_actual'];
        $stockDisponible = (float) $relacion['item_stock_actual'];
        $itemId = (int) $relacion['inventory_item_id'];
        $servicioId = (int) $relacion['servicio_id'];
        $itemNombre = $relacion['item_nombre'];
        $itemSku = $relacion['item_sku'];
        $numeroServicio = $relacion['o_servicio'];
        $costoUnitario = (float) $relacion['costo_unitario'];

        // No hacer nada si la cantidad es la misma
        if (abs($nuevaCantidad - $cantidadActual) < 0.00001) {
            throw new Exception("La nueva cantidad es igual a la actual ($cantidadActual)");
        }

        // PASO 10: Calcular diferencia y validar stock
        $diferencia = $nuevaCantidad - $cantidadActual;
        $esAumento = $diferencia > 0;

        // Si es aumento, verificar que hay suficiente stock
        if ($esAumento && $diferencia > $stockDisponible) {
            throw new Exception(
                "Stock insuficiente para aumentar cantidad. " .
                "Disponible: $stockDisponible, necesario: $diferencia"
            );
        }

        // PASO 11: Actualizar la relación servicio-repuesto
        $stmtUpdate = $conn->prepare("
            UPDATE servicio_repuestos 
            SET cantidad = ?,
                notas = CASE 
                    WHEN ? IS NOT NULL THEN ? 
                    ELSE notas 
                END,
                updated_at = NOW(),
                updated_by = ?
            WHERE id = ?
        ");
        $stmtUpdate->bind_param("dssii", $nuevaCantidad, $notas, $notas, $usuarioActualiza, $servicioRepuestoId);

        if (!$stmtUpdate->execute()) {
            throw new Exception("Error actualizando cantidad: " . $stmtUpdate->error);
        }

        // PASO 12: Actualizar stock del inventario
        if ($esAumento) {
            // Descontar más stock
            $stmtStock = $conn->prepare("
                UPDATE inventory_items 
                SET current_stock = current_stock - ?,
                    updated_at = NOW()
                WHERE id = ?
            ");
            $stmtStock->bind_param("di", $diferencia, $itemId);
        } else {
            // Devolver stock (diferencia es negativa, así que usamos valor absoluto)
            $cantidadDevolver = abs($diferencia);
            $stmtStock = $conn->prepare("
                UPDATE inventory_items 
                SET current_stock = current_stock + ?,
                    updated_at = NOW()
                WHERE id = ?
            ");
            $stmtStock->bind_param("di", $cantidadDevolver, $itemId);
        }

        if (!$stmtStock->execute()) {
            throw new Exception("Error actualizando stock: " . $stmtStock->error);
        }

        // PASO 13: Crear movimiento de inventario
        $movementType = $esAumento ? 'salida' : 'entrada';
        $movementReason = $esAumento ? 'uso_servicio' : 'devolucion';
        $movementQuantity = abs($diferencia);
        $nuevoStockInventario = $stockDisponible - $diferencia;

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
            ) VALUES (?, ?, ?, ?, ?, ?, ?, 'SERVICE', ?, ?, ?, NOW())
        ");

        $movementNotes = $esAumento
            ? "Aumento en servicio #$numeroServicio: $cantidadActual → $nuevaCantidad"
            : "Reducción en servicio #$numeroServicio: $cantidadActual → $nuevaCantidad";

        if (!empty($notas)) {
            $movementNotes .= " - $notas";
        }

        // CORREGIDO: Se agregaron previous_stock(d) y new_stock(d)
        // inventory_item_id(i), movement_type(s), movement_reason(s), quantity(d), previous_stock(d), new_stock(d), unit_cost(d), reference_id(i), notes(s), created_by(i)
        $stmtMovement->bind_param(
            "issddddisi",
            $itemId,
            $movementType,
            $movementReason,
            $movementQuantity,
            $stockDisponible,
            $nuevoStockInventario,
            $costoUnitario,
            $servicioId,
            $movementNotes,
            $usuarioActualiza
        );
        $stmtMovement->execute(); // No es crítico si falla

        // PASO 14: Obtener datos actualizados para la respuesta
        $stmtUpdated = $conn->prepare("
            SELECT 
                sr.*,
                i.current_stock as nuevo_stock,
                (sr.cantidad * sr.costo_unitario) as nuevo_costo_total
            FROM servicio_repuestos sr
            INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
            WHERE sr.id = ?
        ");
        $stmtUpdated->bind_param("i", $servicioRepuestoId);
        $stmtUpdated->execute();
        $updatedResult = $stmtUpdated->get_result();
        $datosActualizados = $updatedResult->fetch_assoc();

        // PASO 15: Log de auditoría (opcional)
        try {
            $stmtAudit = $conn->prepare("
                INSERT INTO audit_log (
                    tabla, 
                    operacion, 
                    registro_id, 
                    datos_anteriores, 
                    datos_nuevos,
                    usuario_id, 
                    fecha_operacion
                ) VALUES (?, 'UPDATE', ?, ?, ?, ?, NOW())
            ");

            $datosAnteriores = json_encode([
                'cantidad' => $cantidadActual,
                'costo_total' => $cantidadActual * $costoUnitario
            ]);

            $datosNuevos = json_encode([
                'cantidad' => $nuevaCantidad,
                'costo_total' => $nuevaCantidad * $costoUnitario,
                'diferencia' => $diferencia,
                'motivo' => $notas
            ]);

            $tabla = 'servicio_repuestos';
            $stmtAudit->bind_param("sissi", $tabla, $servicioRepuestoId, $datosAnteriores, $datosNuevos, $usuarioActualiza);
            $stmtAudit->execute();
        } catch (Exception $auditError) {
            // Log el error de auditoría pero no fallar la operación principal
            error_log("Warning: No se pudo crear log de auditoría: " . $auditError->getMessage());
        }

        // COMMIT de la transacción
        $conn->commit();

        // PASO 16: Preparar respuesta
        $response = [
            'success' => true,
            'data' => [
                'repuesto_actualizado' => [
                    'id' => $servicioRepuestoId,
                    'servicio_id' => $servicioId,
                    'inventory_item_id' => $itemId,
                    'cantidad' => (int) $datosActualizados['cantidad'],
                    'costo_unitario' => (float) $datosActualizados['costo_unitario'],
                    'costo_total' => (float) $datosActualizados['nuevo_costo_total'],
                    'notas' => $datosActualizados['notas'],
                    'usuario_asigno' => (int) $datosActualizados['usuario_asigno'],
                    'fecha_asignacion' => $datosActualizados['fecha_asignacion'],
                    // Información del item
                    'item_sku' => $itemSku,
                    'item_nombre' => $itemNombre,
                    'item_stock_actual' => (int) $datosActualizados['nuevo_stock']
                ],
                'cambios' => [
                    'cantidad_anterior' => $cantidadActual,
                    'cantidad_nueva' => $nuevaCantidad,
                    'diferencia' => $diferencia,
                    'tipo_cambio' => $esAumento ? 'AUMENTO' : 'REDUCCIÓN',
                    'costo_anterior' => round($cantidadActual * $costoUnitario, 2),
                    'costo_nuevo' => round($nuevaCantidad * $costoUnitario, 2),
                    'diferencia_costo' => round($diferencia * $costoUnitario, 2)
                ],
                'stock_info' => [
                    'stock_anterior' => $stockDisponible,
                    'stock_actual' => (int) $datosActualizados['nuevo_stock'],
                    'movimiento_stock' => $esAumento ? -$diferencia : abs($diferencia)
                ]
            ],
            'message' => "Cantidad del repuesto '$itemNombre' en servicio #$numeroServicio actualizada: $cantidadActual → $nuevaCantidad",
            'processed_by' => $currentUser['usuario'],
            'user_role' => $currentUser['rol']
        ];

        sendJsonResponse($response);
    } catch (Exception $e) {
        // ROLLBACK en caso de error
        $conn->rollback();
        throw $e;
    }
} catch (Exception $e) {
    error_log("Error en actualizar_cantidad_repuesto.php: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error actualizando cantidad del repuesto: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->autocommit(true); // Restaurar autocommit
    $conn->close();
}
