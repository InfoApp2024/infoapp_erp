<?php
/**
 * POST /api/inventory/movements/create_movement.php
 * 
 * Endpoint para registrar un nuevo movimiento de inventario
 * Actualiza automáticamente el stock del item y calcula costos promedio
 * 
 * Campos requeridos:
 * - inventory_item_id: int (ID del item) O sku: string (SKU del item)
 * - movement_type: enum('entrada', 'salida', 'ajuste', 'transferencia')
 * - movement_reason: enum('compra', 'venta', 'uso_servicio', 'devolucion', 'ajuste_inventario', 'perdida', 'dañado')
 * - quantity: int (cantidad del movimiento, positivo)
 * 
 * Campos opcionales:
 * - unit_cost: decimal (costo unitario, requerido para entradas)
 * - reference_type: enum('service', 'purchase', 'manual', 'adjustment')
 * - reference_id: int (ID de referencia)
 * - notes: string (notas adicionales)
 * - document_number: string (número de documento)
 * - created_by: int (ID del usuario, default: 1)
 */

require_once '../../backend/login/auth_middleware.php';
$currentUser = requireAuth();

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido',
        'errors' => ['method' => 'Solo se permite método POST']
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Incluir archivo de conexión a la base de datos
require_once '../../../config/database.php';

try {
    // Crear conexión a la base de datos
    $database = new Database();
    $db = $database->getConnection();
    
    // Obtener datos del cuerpo de la petición
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('No se recibieron datos válidos en formato JSON');
    }
    
    // Validar campos requeridos
    $required_fields = ['movement_type', 'movement_reason', 'quantity'];
    $errors = [];
    
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || (is_string($input[$field]) && empty(trim($input[$field])))) {
            $errors[$field] = "El campo {$field} es requerido";
        }
    }
    
    // Validar que se proporcione identificador del item
    if (!isset($input['inventory_item_id']) && !isset($input['sku'])) {
        $errors['item_identifier'] = "Se requiere proporcionar 'inventory_item_id' o 'sku' del item";
    }
    
    // Validar tipos de movimiento
    $valid_movement_types = ['entrada', 'salida', 'ajuste', 'transferencia'];
    if (isset($input['movement_type']) && !in_array($input['movement_type'], $valid_movement_types)) {
        $errors['movement_type'] = "El tipo de movimiento debe ser uno de: " . implode(', ', $valid_movement_types);
    }
    
    // Validar razones de movimiento
    $valid_reasons = ['compra', 'venta', 'uso_servicio', 'devolucion', 'ajuste_inventario', 'perdida', 'dañado'];
    if (isset($input['movement_reason']) && !in_array($input['movement_reason'], $valid_reasons)) {
        $errors['movement_reason'] = "La razón del movimiento debe ser una de: " . implode(', ', $valid_reasons);
    }
    
    // Validar cantidad
    if (isset($input['quantity']) && (!is_numeric($input['quantity']) || intval($input['quantity']) <= 0)) {
        $errors['quantity'] = "La cantidad debe ser un número entero positivo";
    }
    
    // Validar costo unitario para entradas
    if (isset($input['movement_type']) && $input['movement_type'] === 'entrada') {
        if (!isset($input['unit_cost']) || !is_numeric($input['unit_cost']) || floatval($input['unit_cost']) < 0) {
            $errors['unit_cost'] = "El costo unitario es requerido y debe ser un número positivo para movimientos de entrada";
        }
    }
    
    // Si hay errores de validación, devolver error 400
    if (!empty($errors)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Errores de validación',
            'errors' => $errors
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // Obtener información del item
    $item_sql = "SELECT id, sku, name, current_stock, unit_cost, average_cost FROM inventory_items WHERE ";
    $item_params = [];
    
    if (isset($input['inventory_item_id'])) {
        $item_sql .= "id = :item_id";
        $item_params[':item_id'] = intval($input['inventory_item_id']);
    } else {
        $item_sql .= "sku = :sku";
        $item_params[':sku'] = trim($input['sku']);
    }
    
    $item_sql .= " AND is_active = 1";
    
    $item_stmt = $db->prepare($item_sql);
    $item_stmt->execute($item_params);
    $item = $item_stmt->fetch(PDO::FETCH_ASSOC);
    
    if (!$item) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Item no encontrado',
            'errors' => ['item' => 'El item especificado no existe o está inactivo']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // Preparar datos del movimiento
    $quantity = intval($input['quantity']);
    $movement_type = $input['movement_type'];
    $movement_reason = $input['movement_reason'];
    $previous_stock = intval($item['current_stock']);
    $unit_cost = isset($input['unit_cost']) ? floatval($input['unit_cost']) : floatval($item['unit_cost']);
    $total_cost = $quantity * $unit_cost;
    
    // Calcular nuevo stock según el tipo de movimiento
    $new_stock = $previous_stock;
    
    switch ($movement_type) {
        case 'entrada':
            $new_stock = $previous_stock + $quantity;
            break;
        case 'salida':
            $new_stock = $previous_stock - $quantity;
            if ($new_stock < 0) {
                http_response_code(400);
                echo json_encode([
                    'success' => false,
                    'message' => 'Stock insuficiente',
                    'errors' => ['stock' => "No hay suficiente stock. Stock actual: {$previous_stock}, cantidad solicitada: {$quantity}"]
                ], JSON_UNESCAPED_UNICODE);
                exit();
            }
            break;
        case 'ajuste':
            // Para ajustes, la cantidad puede ser positiva (aumento) o negativa (disminución)
            $adjustment_quantity = isset($input['adjustment_type']) && $input['adjustment_type'] === 'decrease' ? -$quantity : $quantity;
            $new_stock = $previous_stock + $adjustment_quantity;
            $quantity = $adjustment_quantity; // Guardar la cantidad con signo
            if ($new_stock < 0) {
                http_response_code(400);
                echo json_encode([
                    'success' => false,
                    'message' => 'El ajuste resultaría en stock negativo',
                    'errors' => ['stock' => "El ajuste no se puede realizar. Stock actual: {$previous_stock}"]
                ], JSON_UNESCAPED_UNICODE);
                exit();
            }
            break;
        case 'transferencia':
            // Para transferencias, manejar como salida por ahora
            $new_stock = $previous_stock - $quantity;
            if ($new_stock < 0) {
                http_response_code(400);
                echo json_encode([
                    'success' => false,
                    'message' => 'Stock insuficiente para transferencia',
                    'errors' => ['stock' => "No hay suficiente stock para transferir. Stock actual: {$previous_stock}"]
                ], JSON_UNESCAPED_UNICODE);
                exit();
            }
            break;
    }
    
    // Calcular nuevo costo promedio (solo para entradas)
    $new_average_cost = floatval($item['average_cost']);
    $new_unit_cost = floatval($item['unit_cost']);
    
    if ($movement_type === 'entrada' && $new_stock > 0) {
        $total_value_before = $previous_stock * $new_average_cost;
        $total_value_added = $quantity * $unit_cost;
        $new_average_cost = ($total_value_before + $total_value_added) / $new_stock;
        $new_unit_cost = $unit_cost; // Actualizar último costo
    }
    
    // Iniciar transacción
    $db->beginTransaction();
    
    try {
        // Insertar movimiento
        $movement_sql = "INSERT INTO inventory_movements (
            inventory_item_id, movement_type, movement_reason,
            quantity, previous_stock, new_stock, unit_cost, total_cost,
            reference_type, reference_id, notes, document_number, created_by
        ) VALUES (
            :item_id, :movement_type, :movement_reason,
            :quantity, :previous_stock, :new_stock, :unit_cost, :total_cost,
            :reference_type, :reference_id, :notes, :document_number, :created_by
        )";
        
        $movement_data = [
            ':item_id' => $item['id'],
            ':movement_type' => $movement_type,
            ':movement_reason' => $movement_reason,
            ':quantity' => $quantity,
            ':previous_stock' => $previous_stock,
            ':new_stock' => $new_stock,
            ':unit_cost' => $unit_cost,
            ':total_cost' => $total_cost,
            ':reference_type' => isset($input['reference_type']) ? $input['reference_type'] : null,
            ':reference_id' => isset($input['reference_id']) ? intval($input['reference_id']) : null,
            ':notes' => isset($input['notes']) ? trim($input['notes']) : null,
            ':document_number' => isset($input['document_number']) ? trim($input['document_number']) : null,
            ':created_by' => isset($input['created_by']) ? intval($input['created_by']) : 1
        ];
        
        $movement_stmt = $db->prepare($movement_sql);
        $movement_stmt->execute($movement_data);
        $movement_id = $db->lastInsertId();
        
        // Actualizar stock del item
        $update_item_sql = "UPDATE inventory_items 
                           SET current_stock = :new_stock,
                               average_cost = :average_cost,
                               last_cost = :unit_cost,
                               updated_at = CURRENT_TIMESTAMP
                           WHERE id = :item_id";
        
        $update_data = [
            ':new_stock' => $new_stock,
            ':average_cost' => $new_average_cost,
            ':unit_cost' => $new_unit_cost,
            ':item_id' => $item['id']
        ];
        
        $update_stmt = $db->prepare($update_item_sql);
        $update_stmt->execute($update_data);
        
        // Confirmar transacción
        $db->commit();
        
        // Obtener el movimiento creado con información completa
        $get_movement_sql = "SELECT 
            im.*,
            ii.sku,
            ii.name as item_name
        FROM inventory_movements im
        INNER JOIN inventory_items ii ON im.inventory_item_id = ii.id
        WHERE im.id = :movement_id";
        
        $get_movement_stmt = $db->prepare($get_movement_sql);
        $get_movement_stmt->execute([':movement_id' => $movement_id]);
        $created_movement = $get_movement_stmt->fetch(PDO::FETCH_ASSOC);
        
        // Determinar alertas
        $alerts = [];
        if ($new_stock == 0) {
            $alerts[] = [
                'type' => 'warning',
                'message' => 'El item quedó sin stock después del movimiento'
            ];
        } elseif ($new_stock <= 5) { // Ejemplo de umbral bajo
            $alerts[] = [
                'type' => 'info',
                'message' => 'El item tiene stock bajo después del movimiento'
            ];
        }
        
        // Respuesta exitosa
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Movimiento registrado exitosamente',
            'data' => [
                'movement' => $created_movement,
                'stock_update' => [
                    'previous_stock' => $previous_stock,
                    'new_stock' => $new_stock,
                    'stock_change' => $new_stock - $previous_stock,
                    'new_average_cost' => $new_average_cost,
                    'movement_value' => $total_cost
                ],
                'alerts' => $alerts
            ]
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        // Revertir transacción
        $db->rollBack();
        throw $e;
    }
    
} catch (PDOException $e) {
    // Error de base de datos
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error de base de datos',
        'errors' => ['database' => 'Error al registrar el movimiento: ' . $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    // Error general
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Error en la petición',
        'errors' => ['general' => $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
}

/**
 * Ejemplos de peticiones JSON:
 * 
 * // Entrada de inventario (compra)
 * {
 *   "inventory_item_id": 1,
 *   "movement_type": "entrada",
 *   "movement_reason": "compra",
 *   "quantity": 20,
 *   "unit_cost": 16.00,
 *   "reference_type": "purchase",
 *   "reference_id": 101,
 *   "notes": "Compra a proveedor principal",
 *   "document_number": "FAC-2025-001",
 *   "created_by": 1
 * }
 * 
 * // Salida de inventario (uso en servicio)
 * {
 *   "sku": "REP001",
 *   "movement_type": "salida",
 *   "movement_reason": "uso_servicio",
 *   "quantity": 2,
 *   "reference_type": "service",
 *   "reference_id": 123,
 *   "notes": "Usado en mantenimiento preventivo",
 *   "created_by": 1
 * }
 * 
 * // Ajuste de inventario
 * {
 *   "inventory_item_id": 1,
 *   "movement_type": "ajuste",
 *   "movement_reason": "ajuste_inventario",
 *   "quantity": 5,
 *   "adjustment_type": "increase",
 *   "notes": "Ajuste por conteo físico",
 *   "created_by": 1
 * }
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Movimiento registrado exitosamente",
 *   "data": {
 *     "movement": {
 *       "id": 6,
 *       "inventory_item_id": 1,
 *       "movement_type": "entrada",
 *       "movement_reason": "compra",
 *       "quantity": 20,
 *       "previous_stock": 25,
 *       "new_stock": 45,
 *       "unit_cost": 16.00,
 *       "total_cost": 320.00,
 *       "reference_type": "purchase",
 *       "reference_id": 101,
 *       "notes": "Compra a proveedor principal",
 *       "document_number": "FAC-2025-001",
 *       "created_by": 1,
 *       "created_at": "2025-01-15 15:30:00",
 *       "sku": "REP001",
 *       "item_name": "Filtro de Aceite"
 *     },
 *     "stock_update": {
 *       "previous_stock": 25,
 *       "new_stock": 45,
 *       "stock_change": 20,
 *       "new_average_cost": 15.67,
 *       "movement_value": 320.00
 *     },
 *     "alerts": []
 *   }
 * }
 */
?>