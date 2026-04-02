<?php

/**
 * POST /API_Infoapp/inventory/movements/create_movement.php
 * 
 * Endpoint para crear un nuevo movimiento de inventario
 * Actualiza automáticamente el stock del item
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['success' => false, 'message' => 'Método no permitido']);
    exit();
}

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null)
{
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

try {
    // Incluir archivo de conexión
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }

    // Obtener datos del cuerpo de la petición
    $inputRaw = file_get_contents('php://input');
    $input = json_decode($inputRaw, true);

    if (!$input) {
        sendErrorResponse(400, 'No se recibieron datos válidos en formato JSON');
    }

    // === VALIDACIONES DE CAMPOS REQUERIDOS ===
    $required_fields = ['inventory_item_id', 'movement_type', 'movement_reason', 'quantity'];
    $errors = [];

    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || $input[$field] === '' || $input[$field] === null) {
            $errors[$field] = "El campo {$field} es requerido";
        }
    }

    // === VALIDAR TIPOS DE MOVIMIENTO ===
    $valid_movement_types = ['entrada', 'salida', 'ajuste', 'transferencia'];
    if (isset($input['movement_type']) && !in_array($input['movement_type'], $valid_movement_types)) {
        $errors['movement_type'] = "El tipo de movimiento debe ser uno de: " . implode(', ', $valid_movement_types);
    }

    // === VALIDAR CANTIDAD ===
    if (isset($input['quantity']) && (!is_numeric($input['quantity']) || floatval($input['quantity']) <= 0)) {
        $errors['quantity'] = "La cantidad debe ser un número positivo";
    }

    // === VALIDAR CAMPOS NUMÉRICOS OPCIONALES ===
    if (!empty($input['unit_cost']) && !is_numeric($input['unit_cost'])) {
        $errors['unit_cost'] = "El costo unitario debe ser un número válido";
    }

    if (!empty($input['reference_id']) && !is_numeric($input['reference_id'])) {
        $errors['reference_id'] = "El ID de referencia debe ser un número válido";
    }

    if (!empty($input['created_by']) && !is_numeric($input['created_by'])) {
        $errors['created_by'] = "El ID del usuario debe ser un número válido";
    }

    // Si hay errores de validación, devolver error 400
    if (!empty($errors)) {
        sendErrorResponse(400, 'Errores de validación', $errors);
    }

    // === OBTENER EL ITEM DE INVENTARIO ===
    $inventory_item_id = intval($input['inventory_item_id']);

    $get_item_sql = "SELECT * FROM inventory_items WHERE id = ? AND is_active = 1";
    $get_item_stmt = $conn->prepare($get_item_sql);

    if (!$get_item_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de item');
    }

    $get_item_stmt->bind_param("i", $inventory_item_id);
    $get_item_stmt->execute();
    $item_result = $get_item_stmt->get_result();
    $item = $item_result->fetch_assoc();
    $get_item_stmt->close();

    if (!$item) {
        sendErrorResponse(404, 'El item de inventario especificado no existe o está inactivo');
    }

    // === PREPARAR DATOS DEL MOVIMIENTO ===
    $movement_type = $input['movement_type'];
    $movement_reason = $input['movement_reason'];
    $quantity = floatval($input['quantity']);
    // === DETERMINAR COSTO UNITARIO DEL MOVIMIENTO ===
    // Si se proporciona un costo unitario, usarlo (típico en compras/entradas)
    // Si no, determinar según el tipo de movimiento
    if (!empty($input['unit_cost'])) {
        $unit_cost = floatval($input['unit_cost']);
    } else {
        if ($movement_type === 'salida' || $movement_type === 'transferencia') {
            // Para salidas, el costo es el Costo Promedio actual (valor de inventario que sale)
            $unit_cost = floatval($item['average_cost']);
        } else {
            // Para entradas sin costo explícito, usar el Último Costo o Costo Inicial o Precio Unitario (fallback)
            // Prioridad: Last Cost > Initial Cost > Unit Cost (Precio Venta)
            if (floatval($item['last_cost']) > 0) {
                $unit_cost = floatval($item['last_cost']);
            } elseif (isset($item['initial_cost']) && floatval($item['initial_cost']) > 0) {
                $unit_cost = floatval($item['initial_cost']);
            } else {
                $unit_cost = floatval($item['unit_cost']);
            }
        }
    }

    $reference_type = isset($input['reference_type']) ? trim($input['reference_type']) : null;
    $reference_id = !empty($input['reference_id']) ? intval($input['reference_id']) : null;
    $notes = isset($input['notes']) ? trim($input['notes']) : null;
    $document_number = isset($input['document_number']) ? trim($input['document_number']) : null;
    $created_by = !empty($input['created_by']) ? intval($input['created_by']) : null;

    // === CALCULAR NUEVO STOCK ===
    $previous_stock = floatval($item['current_stock']);
    $new_stock = $previous_stock;

    switch ($movement_type) {
        case 'entrada':
            $new_stock = $previous_stock + $quantity;
            break;
        case 'salida':
            $new_stock = $previous_stock - $quantity;
            break;
        case 'ajuste':
            // Para ajustes, la cantidad representa el nuevo stock total
            $new_stock = $quantity;
            $quantity = abs($new_stock - $previous_stock); // Recalcular cantidad para el registro
            break;
        case 'transferencia':
            // Para transferencias, manejar como salida por ahora
            $new_stock = $previous_stock - $quantity;
            break;
    }

    // === VALIDAR QUE EL STOCK NO SEA NEGATIVO ===
    if ($new_stock < 0) {
        sendErrorResponse(400, 'No se puede realizar el movimiento', [
            'stock' => "El movimiento resultaría en stock negativo. Stock actual: {$previous_stock}, cantidad solicitada: {$quantity}"
        ]);
    }

    $total_cost = $quantity * $unit_cost;

    // === CALCULAR NUEVOS COSTOS (PROMEDIO PONDERADO) ===
    $new_average_cost = floatval($item['average_cost']);
    $new_last_cost = floatval($item['last_cost']);

    if ($movement_type === 'entrada') {
        $new_last_cost = $unit_cost;

        $current_val = $previous_stock * floatval($item['average_cost']);
        $incoming_val = $quantity * $unit_cost;
        // En entrada, $new_stock ya es ($previous_stock + $quantity)
        $total_qty = $new_stock;

        if ($total_qty > 0) {
            $new_average_cost = ($current_val + $incoming_val) / $total_qty;
        } else {
            $new_average_cost = $unit_cost;
        }
    }
    // TODO: Manejar ajustes positivos si se requiere recalcular costo

    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);

    try {
        // === INSERTAR MOVIMIENTO ===
        // CORREGIDO: 13 parámetros con tipos correctos
        $insert_movement_sql = "INSERT INTO inventory_movements (
            inventory_item_id, movement_type, movement_reason,
            quantity, previous_stock, new_stock, unit_cost, total_cost,
            reference_type, reference_id, notes, document_number, created_by, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())";

        $insert_stmt = $conn->prepare($insert_movement_sql);
        if (!$insert_stmt) {
            throw new Exception("Error preparando inserción de movimiento: " . $conn->error);
        }

        // CORREGIDO: Cadena de tipos con 13 caracteres para 13 parámetros
        // i s s d d d d d s i s s i
        $insert_stmt->bind_param(
            "issdddddsissi",
            $inventory_item_id,    // i - integer
            $movement_type,        // s - string
            $movement_reason,      // s - string
            $quantity,             // d - double
            $previous_stock,       // d - double
            $new_stock,            // d - double
            $unit_cost,            // d - double
            $total_cost,           // d - double
            $reference_type,       // s - string (puede ser null)
            $reference_id,         // i - integer (puede ser null)
            $notes,                // s - string (puede ser null)
            $document_number,      // s - string (puede ser null)
            $created_by            // i - integer (puede ser null)
        );

        if (!$insert_stmt->execute()) {
            throw new Exception("Error al insertar el movimiento: " . $insert_stmt->error);
        }

        $movement_id = $conn->insert_id;
        $insert_stmt->close();

        // === ACTUALIZAR STOCK Y COSTOS DEL ITEM ===
        // Si se envió un nuevo precio de venta, lo actualizamos también
        $new_sale_price_sql = "";
        if (isset($input['new_sale_price']) && is_numeric($input['new_sale_price'])) {
            $new_sale_price_sql = ", unit_cost = " . floatval($input['new_sale_price']);
        }

        $update_stock_sql = "UPDATE inventory_items SET 
        current_stock = ?, 
        average_cost = ?,
        last_cost = ?, 
        updated_at = NOW()
        $new_sale_price_sql 
        WHERE id = ?";

        $update_stmt = $conn->prepare($update_stock_sql);
        if (!$update_stmt) {
            throw new Exception("Error preparando actualización de stock: " . $conn->error);
        }

        $update_stmt->bind_param("iddi", $new_stock, $new_average_cost, $new_last_cost, $inventory_item_id);

        if (!$update_stmt->execute()) {
            throw new Exception("Error al actualizar el stock: " . $update_stmt->error);
        }

        $update_stmt->close();

        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();

        // === OBTENER EL MOVIMIENTO CREADO CON INFORMACIÓN COMPLETA ===
        // === OBTENER EL MOVIMIENTO CREADO CON INFORMACIÓN COMPLETA ===
        $get_movement_sql = "SELECT 
    m.*,
    i.name as item_name,
    i.sku as item_sku,
    i.unit_of_measure
FROM inventory_movements m
LEFT JOIN inventory_items i ON m.inventory_item_id = i.id
WHERE m.id = ?";

        $get_movement_stmt = $conn->prepare($get_movement_sql);
        if (!$get_movement_stmt) {
            throw new Exception("Error preparando consulta de movimiento: " . $conn->error);
        }

        $get_movement_stmt->bind_param("i", $movement_id);
        $get_movement_stmt->execute();
        $movement_result = $get_movement_stmt->get_result();
        $created_movement = $movement_result->fetch_assoc();
        $get_movement_stmt->close();

        if (!$created_movement) {
            throw new Exception("No se pudo obtener el movimiento creado");
        }

        // === FORMATEAR DATOS DEL MOVIMIENTO ===
        $created_movement['id'] = intval($created_movement['id']);
        $created_movement['inventory_item_id'] = intval($created_movement['inventory_item_id']);
        $created_movement['quantity'] = floatval($created_movement['quantity']);
        $created_movement['previous_stock'] = floatval($created_movement['previous_stock']);
        $created_movement['new_stock'] = floatval($created_movement['new_stock']);
        $created_movement['unit_cost'] = floatval($created_movement['unit_cost']);
        $created_movement['total_cost'] = floatval($created_movement['total_cost']);
        $created_movement['reference_id'] = $created_movement['reference_id'] ? intval($created_movement['reference_id']) : null;
        $created_movement['created_by'] = $created_movement['created_by'] ? intval($created_movement['created_by']) : null;

        // === GENERAR ALERTAS SI ES NECESARIO ===
        $alerts = [];

        // Alerta de stock bajo
        if ($new_stock <= intval($item['minimum_stock']) && intval($item['minimum_stock']) > 0) {
            $alerts[] = [
                'type' => 'warning',
                'message' => 'El stock ha quedado por debajo del mínimo recomendado',
                'level' => 'low_stock'
            ];
        }

        // Alerta de stock crítico
        if ($new_stock == 0) {
            $alerts[] = [
                'type' => 'critical',
                'message' => 'El item ha quedado sin stock',
                'level' => 'out_of_stock'
            ];
        }

        // === INFORMACIÓN DEL STOCK ===
        $stock_update = [
            'previous_stock' => $previous_stock,
            'new_stock' => $new_stock,
            'stock_change' => $new_stock - $previous_stock,
            'stock_status' => $new_stock == 0 ? 'sin_stock' : ($new_stock <= intval($item['minimum_stock']) ? 'stock_bajo' : 'stock_normal'),
            'estimated_value' => $new_stock * floatval($item['unit_cost'])
        ];

        // === RESPUESTA EXITOSA ===
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Movimiento de inventario creado exitosamente',
            'data' => [
                'movement' => $created_movement,
                'stock_update' => $stock_update,
                'alerts' => $alerts
            ]
        ], JSON_UNESCAPED_UNICODE);
    } catch (Exception $e) {
        // Revertir transacción
        $conn->rollback();
        throw $e;
    } finally {
        // Restaurar autocommit
        $conn->autocommit(true);
    }
} catch (Exception $e) {
    // Error general
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
