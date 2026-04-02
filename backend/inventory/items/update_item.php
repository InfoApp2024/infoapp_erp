<?php
/**
 * PUT/PATCH /API_Infoapp/inventory/items/update_item.php
 * 
 * Endpoint para actualizar un item de inventario existente
 * Incluye validaciones completas y manejo de cambios de stock
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/update_item.php', 'update_item');

header('Content-Type: application/json');

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null) {
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Manejar preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir métodos PUT y PATCH
if (!in_array($_SERVER['REQUEST_METHOD'], ['PUT', 'PATCH'])) {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permiten métodos PUT y PATCH']);
}

try {
    // Incluir archivo de conexión existente
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
    
    // === VALIDAR QUE SE PROPORCIONE EL ID ===
    if (!isset($input['id']) || empty($input['id'])) {
        sendErrorResponse(400, 'Se requiere el ID del item para actualizar');
    }
    
    $item_id = intval($input['id']);
    
    // === VERIFICAR QUE EL ITEM EXISTS ===
    $check_item_sql = "SELECT * FROM inventory_items WHERE id = ?";
    $check_stmt = $conn->prepare($check_item_sql);
    
    if (!$check_stmt) {
        sendErrorResponse(500, 'Error preparando consulta de verificación');
    }
    
    $check_stmt->bind_param("i", $item_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    $existing_item = $check_result->fetch_assoc();
    $check_stmt->close();
    
    if (!$existing_item) {
        sendErrorResponse(404, 'El item especificado no existe');
    }
    
    // === VALIDACIONES DE CAMPOS REQUERIDOS ===
    $required_fields = ['sku', 'name', 'item_type'];
    $errors = [];
    
    foreach ($required_fields as $field) {
        if (!isset($input[$field]) || empty(trim($input[$field]))) {
            $errors[$field] = "El campo {$field} es requerido";
        }
    }
    
    // === VALIDAR TIPO DE ITEM ===
    // Se permite cualquier valor de texto para el tipo de item (validación dinámica)
    if (!isset($input['item_type']) || empty(trim($input['item_type']))) {
        $errors['item_type'] = "El tipo de item es requerido";
    }
    
    // === VALIDAR SKU ÚNICO (EXCLUYENDO EL ITEM ACTUAL) ===
    if (isset($input['sku']) && !empty($input['sku'])) {
        $sku_value = trim($input['sku']);
        
        // Solo verificar si el SKU cambió
        if ($sku_value !== $existing_item['sku']) {
            $check_sku_sql = "SELECT COUNT(*) as count FROM inventory_items WHERE sku = ? AND id != ?";
            $check_sku_stmt = $conn->prepare($check_sku_sql);
            
            if (!$check_sku_stmt) {
                sendErrorResponse(500, 'Error preparando consulta SKU');
            }
            
            $check_sku_stmt->bind_param("si", $sku_value, $item_id);
            $check_sku_stmt->execute();
            $sku_result = $check_sku_stmt->get_result();
            $sku_count = $sku_result->fetch_assoc()['count'];
            $check_sku_stmt->close();
            
            if ($sku_count > 0) {
                $errors['sku'] = "El SKU '{$input['sku']}' ya existe en el sistema";
            }
        }
    }
    
    // === VALIDAR CATEGORÍA (SI SE PROPORCIONA) ===
    if (!empty($input['category_id'])) {
        if (!is_numeric($input['category_id'])) {
            $errors['category_id'] = "La categoría debe ser un número válido";
        } else {
            $check_category_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE id = ? AND is_active = 1";
            $check_category_stmt = $conn->prepare($check_category_sql);
            
            if ($check_category_stmt) {
                $category_id = intval($input['category_id']);
                $check_category_stmt->bind_param("i", $category_id);
                $check_category_stmt->execute();
                $category_result = $check_category_stmt->get_result();
                $category_count = $category_result->fetch_assoc()['count'];
                $check_category_stmt->close();
                
                if ($category_count == 0) {
                    $errors['category_id'] = "La categoría especificada no existe o está inactiva";
                }
            }
        }
    }
    
    // === VALIDAR PROVEEDOR (SI SE PROPORCIONA) ===
    if (!empty($input['supplier_id'])) {
        if (!is_numeric($input['supplier_id'])) {
            $errors['supplier_id'] = "El proveedor debe ser un número válido";
        } else {
            $check_supplier_sql = "SELECT COUNT(*) as count FROM suppliers WHERE id = ? AND is_active = 1";
            $check_supplier_stmt = $conn->prepare($check_supplier_sql);
            
            if ($check_supplier_stmt) {
                $supplier_id = intval($input['supplier_id']);
                $check_supplier_stmt->bind_param("i", $supplier_id);
                $check_supplier_stmt->execute();
                $supplier_result = $check_supplier_stmt->get_result();
                $supplier_count = $supplier_result->fetch_assoc()['count'];
                $check_supplier_stmt->close();
                
                if ($supplier_count == 0) {
                    $errors['supplier_id'] = "El proveedor especificado no existe o está inactivo";
                }
            }
        }
    }
    
    // === VALIDAR CAMPOS NUMÉRICOS ===
    $numeric_fields = ['current_stock', 'minimum_stock', 'maximum_stock', 'unit_cost', 'average_cost', 'last_cost', 'initial_cost'];
    foreach ($numeric_fields as $field) {
        if (!empty($input[$field]) && !is_numeric($input[$field])) {
            $errors[$field] = "El campo {$field} debe ser un número válido";
        }
    }
    
    // Si hay errores de validación, devolver error 400
    if (!empty($errors)) {
        sendErrorResponse(400, 'Errores de validación', $errors);
    }
    
    // === PREPARAR DATOS PARA ACTUALIZACIÓN ===
    $sku = trim($input['sku']);
    $name = trim($input['name']);
    $description = isset($input['description']) ? trim($input['description']) : null;
    $category_id = !empty($input['category_id']) ? intval($input['category_id']) : null;
    $item_type = $input['item_type'];
    $brand = isset($input['brand']) ? trim($input['brand']) : null;
    $model = isset($input['model']) ? trim($input['model']) : null;
    $part_number = isset($input['part_number']) ? trim($input['part_number']) : null;
    $current_stock = isset($input['current_stock']) ? intval($input['current_stock']) : intval($existing_item['current_stock']);
    $minimum_stock = isset($input['minimum_stock']) ? intval($input['minimum_stock']) : intval($existing_item['minimum_stock']);
    $maximum_stock = isset($input['maximum_stock']) ? intval($input['maximum_stock']) : intval($existing_item['maximum_stock']);
    $unit_of_measure = isset($input['unit_of_measure']) ? trim($input['unit_of_measure']) : $existing_item['unit_of_measure'];
    $unit_cost = isset($input['unit_cost']) ? floatval($input['unit_cost']) : floatval($existing_item['unit_cost']);
    $average_cost = isset($input['average_cost']) ? floatval($input['average_cost']) : floatval($existing_item['average_cost']);
    $last_cost = isset($input['last_cost']) ? floatval($input['last_cost']) : floatval($existing_item['last_cost']);
    $location = isset($input['location']) ? trim($input['location']) : $existing_item['location'];
    $shelf = isset($input['shelf']) ? trim($input['shelf']) : $existing_item['shelf'];
    $bin = isset($input['bin']) ? trim($input['bin']) : $existing_item['bin'];
    $barcode = isset($input['barcode']) ? trim($input['barcode']) : $existing_item['barcode'];
    $qr_code = isset($input['qr_code']) ? trim($input['qr_code']) : $existing_item['qr_code'];
    $supplier_id = !empty($input['supplier_id']) ? intval($input['supplier_id']) : ($existing_item['supplier_id'] ? intval($existing_item['supplier_id']) : null);
    $is_active = isset($input['is_active']) ? ($input['is_active'] ? 1 : 0) : intval($existing_item['is_active']);
    
    // === DETECTAR CAMBIO DE STOCK PARA CREAR MOVIMIENTO ===
    $old_stock = intval($existing_item['current_stock']);
    $stock_changed = ($current_stock != $old_stock);
    $movement_created = false;
    
    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);
    
    try {
        // === ACTUALIZAR ITEM DE INVENTARIO ===
        // CORREGIDO: 22 parámetros con tipos correctos (se agregó initial_cost)
        $update_sql = "UPDATE inventory_items SET 
            sku = ?, name = ?, description = ?, category_id = ?, item_type = ?, 
            brand = ?, model = ?, part_number = ?, current_stock = ?, 
            minimum_stock = ?, maximum_stock = ?, unit_of_measure = ?, 
            initial_cost = ?, unit_cost = ?, location = ?, 
            shelf = ?, bin = ?, barcode = ?, qr_code = ?, supplier_id = ?, 
            is_active = ?, updated_at = NOW()
            WHERE id = ?";
        
        $update_stmt = $conn->prepare($update_sql);
        if (!$update_stmt) {
            throw new Exception("Error preparando actualización: " . $conn->error);
        }
        
        // CORREGIDO: Cadena de tipos con 22 caracteres para 22 parámetros
        // s s s i s s s s i i i s d d s s s s s i i
        $update_stmt->bind_param(
            "sssissssiiisddsssssiii",
            $sku,              // s - string
            $name,             // s - string  
            $description,      // s - string (puede ser null)
            $category_id,      // i - integer (puede ser null)
            $item_type,        // s - string
            $brand,            // s - string (puede ser null)
            $model,            // s - string (puede ser null)
            $part_number,      // s - string (puede ser null)
            $current_stock,    // i - integer
            $minimum_stock,    // i - integer
            $maximum_stock,    // i - integer
            $unit_of_measure,  // s - string
            $initial_cost,     // d - double (initial_cost)
            $unit_cost,        // d - double (unit_cost)
            $location,         // s - string (puede ser null)
            $shelf,            // s - string (puede ser null)
            $bin,              // s - string (puede ser null)
            $barcode,          // s - string (puede ser null)
            $qr_code,          // s - string (puede ser null)
            $supplier_id,      // i - integer (puede ser null)
            $is_active,        // i - integer (0 o 1)
            $item_id           // i - integer (WHERE clause)
        );
        
        if (!$update_stmt->execute()) {
            throw new Exception("Error al actualizar el item: " . $update_stmt->error);
        }
        
        $update_stmt->close();
        
        // === CREAR MOVIMIENTO SI EL STOCK CAMBIÓ ===
        if ($stock_changed) {
            $table_check = $conn->query("SHOW TABLES LIKE 'inventory_movements'");
            
            if ($table_check && $table_check->num_rows > 0) {
                $quantity_change = $current_stock - $old_stock;
                $movement_type = $quantity_change > 0 ? 'entrada' : ($quantity_change < 0 ? 'salida' : 'ajuste');
                $quantity_abs = abs($quantity_change);
                
                $movement_sql = "INSERT INTO inventory_movements (
                    inventory_item_id, movement_type, movement_reason,
                    quantity, previous_stock, new_stock, unit_cost, total_cost,
                    notes, created_at
                ) VALUES (?, ?, 'ajuste_inventario', ?, ?, ?, ?, ?, 'Ajuste por edición de item', NOW())";
                
                $total_cost = $quantity_abs * $unit_cost;
                $movement_stmt = $conn->prepare($movement_sql);
                
                if ($movement_stmt) {
                    $movement_stmt->bind_param(
                        "isiiidd",
                        $item_id, $movement_type, $quantity_abs, $old_stock, $current_stock, $unit_cost, $total_cost
                    );
                    
                    if ($movement_stmt->execute()) {
                        $movement_created = true;
                    }
                    $movement_stmt->close();
                }
            }
        }
        
        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();
        
        // === OBTENER ITEM ACTUALIZADO CON INFORMACIÓN COMPLETA ===
        $get_item_sql = "SELECT 
            ii.*,
            ic.name as category_name,
            s.name as supplier_name
        FROM inventory_items ii
        LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
        LEFT JOIN suppliers s ON ii.supplier_id = s.id
        WHERE ii.id = ?";
        
        $get_item_stmt = $conn->prepare($get_item_sql);
        if (!$get_item_stmt) {
            throw new Exception("Error preparando consulta de obtención: " . $conn->error);
        }
        
        $get_item_stmt->bind_param("i", $item_id);
        if (!$get_item_stmt->execute()) {
            throw new Exception("Error ejecutando consulta de obtención: " . $get_item_stmt->error);
        }
        
        $get_result = $get_item_stmt->get_result();
        $updated_item = $get_result->fetch_assoc();
        $get_item_stmt->close();
        
        if (!$updated_item) {
            throw new Exception("No se pudo obtener el item actualizado");
        }
        
        // === FORMATEAR DATOS DEL ITEM ACTUALIZADO ===
        $updated_item['id'] = intval($updated_item['id']);
        $updated_item['current_stock'] = intval($updated_item['current_stock']);
        $updated_item['minimum_stock'] = intval($updated_item['minimum_stock']);
        $updated_item['maximum_stock'] = intval($updated_item['maximum_stock']);
        $updated_item['unit_cost'] = floatval($updated_item['unit_cost']);
        $updated_item['average_cost'] = floatval($updated_item['average_cost']);
        $updated_item['last_cost'] = floatval($updated_item['last_cost']);
        $updated_item['is_active'] = boolval($updated_item['is_active']);
        $updated_item['category_id'] = $updated_item['category_id'] ? intval($updated_item['category_id']) : null;
        $updated_item['supplier_id'] = $updated_item['supplier_id'] ? intval($updated_item['supplier_id']) : null;
        
        // === INFORMACIÓN ADICIONAL ===
        $update_info = [
            'stock_changed' => $stock_changed,
            'old_stock' => $old_stock,
            'new_stock' => $current_stock,
            'movement_created' => $movement_created,
            'has_stock' => $updated_item['current_stock'] > 0,
            'stock_status' => $updated_item['current_stock'] == 0 ? 'sin_stock' : 
                            ($updated_item['current_stock'] <= $updated_item['minimum_stock'] ? 'stock_bajo' : 'stock_normal'),
            'is_complete' => !empty($updated_item['category_id']) && !empty($updated_item['supplier_id']),
            'estimated_value' => $updated_item['current_stock'] * $updated_item['unit_cost']
        ];
        
        // === RESPUESTA EXITOSA ===
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Item de inventario actualizado exitosamente',
            'data' => [
                'item' => $updated_item,
                'update_info' => $update_info
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
?>