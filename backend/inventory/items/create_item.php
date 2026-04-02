<?php

/**
 * POST /API_Infoapp/inventory/items/create_item.php
 * 
 * Endpoint para crear un nuevo item de inventario
 * Incluye validaciones completas y creación automática de movimiento inicial
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/create_item.php', 'create_item');

header('Content-Type: application/json');

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

// Manejar preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método POST']);
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

    // === VALIDAR SKU ÚNICO ===
    if (isset($input['sku']) && !empty($input['sku'])) {
        $check_sku_sql = "SELECT COUNT(*) as count FROM inventory_items WHERE sku = ?";
        $check_stmt = $conn->prepare($check_sku_sql);

        if (!$check_stmt) {
            sendErrorResponse(500, 'Error preparando consulta SKU');
        }

        $sku_value = trim($input['sku']);
        $check_stmt->bind_param("s", $sku_value);
        $check_stmt->execute();
        $sku_result = $check_stmt->get_result();
        $sku_count = $sku_result->fetch_assoc()['count'];
        $check_stmt->close();

        if ($sku_count > 0) {
            $errors['sku'] = "El SKU '{$input['sku']}' ya existe en el sistema";
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

    // === VALIDAR USUARIO CREADOR (SI SE PROPORCIONA) ===
    if (!empty($input['created_by'])) {
        if (!is_numeric($input['created_by'])) {
            $errors['created_by'] = "El usuario debe ser un número válido";
        } else {
            $check_user_sql = "SELECT COUNT(*) as count FROM usuarios WHERE id = ?";
            $check_user_stmt = $conn->prepare($check_user_sql);

            if ($check_user_stmt) {
                $user_id = intval($input['created_by']);
                $check_user_stmt->bind_param("i", $user_id);
                $check_user_stmt->execute();
                $user_result = $check_user_stmt->get_result();
                $user_count = $user_result->fetch_assoc()['count'];
                $check_user_stmt->close();

                if ($user_count == 0) {
                    $errors['created_by'] = "El usuario especificado no existe";
                }
            }
        }
    }

    // === VALIDAR CAMPOS NUMÉRICOS ===
    $numeric_fields = ['current_stock', 'minimum_stock', 'maximum_stock', 'unit_cost'];
    foreach ($numeric_fields as $field) {
        if (!empty($input[$field]) && !is_numeric($input[$field])) {
            $errors[$field] = "El campo {$field} debe ser un número válido";
        }
    }

    // Si hay errores de validación, devolver error 400
    if (!empty($errors)) {
        sendErrorResponse(400, 'Errores de validación', $errors);
    }

    // === PREPARAR DATOS PARA INSERCIÓN ===
    $sku = trim($input['sku']);
    $name = trim($input['name']);
    $description = isset($input['description']) ? trim($input['description']) : null;
    $category_id = !empty($input['category_id']) ? intval($input['category_id']) : null;
    $item_type = $input['item_type'];
    $brand = isset($input['brand']) ? trim($input['brand']) : null;
    $model = isset($input['model']) ? trim($input['model']) : null;
    $part_number = isset($input['part_number']) ? trim($input['part_number']) : null;
    $current_stock = isset($input['current_stock']) ? intval($input['current_stock']) : 0;
    $minimum_stock = isset($input['minimum_stock']) ? intval($input['minimum_stock']) : 0;
    $maximum_stock = isset($input['maximum_stock']) ? intval($input['maximum_stock']) : 0;
    $unit_of_measure = isset($input['unit_of_measure']) ? trim($input['unit_of_measure']) : 'unidad';
    $unit_cost = isset($input['unit_cost']) ? floatval($input['unit_cost']) : 0.00;
    // NUEVO: Costo inicial (costo de adquisición)
    $initial_cost = isset($input['initial_cost']) ? floatval($input['initial_cost']) : 0.00;

    // Lógica para costos:
    // unit_cost = Precio de Venta
    // initial_cost = Costo de Compra inicial
    // average_cost y last_cost se inicializan con initial_cost

    $location = isset($input['location']) ? trim($input['location']) : null;
    $shelf = isset($input['shelf']) ? trim($input['shelf']) : null;
    $bin = isset($input['bin']) ? trim($input['bin']) : null;
    $barcode = isset($input['barcode']) ? trim($input['barcode']) : null;
    $qr_code = isset($input['qr_code']) ? trim($input['qr_code']) : null;
    $supplier_id = !empty($input['supplier_id']) ? intval($input['supplier_id']) : null;

    // === OBTENER USUARIO DE LA SESIÓN O REQUEST ===
    $created_by = null;
    if (isset($input['created_by']) && !empty($input['created_by'])) {
        $created_by = intval($input['created_by']);
    } elseif (isset($input['user_id']) && !empty($input['user_id'])) {
        $created_by = intval($input['user_id']);
    } elseif (isset($_SERVER['HTTP_USER_ID']) && !empty($_SERVER['HTTP_USER_ID'])) {
        $created_by = intval($_SERVER['HTTP_USER_ID']);
    }

    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);

    try {
        // === INSERTAR ITEM DE INVENTARIO ===
        // CORREGIDO: 23 parámetros (agregado initial_cost)
        $insert_sql = "INSERT INTO inventory_items (
            sku, name, description, category_id, item_type, brand, model, part_number,
            current_stock, minimum_stock, maximum_stock, unit_of_measure,
            initial_cost, unit_cost, average_cost, last_cost, location, shelf, bin,
            barcode, qr_code, supplier_id, created_by
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

        $insert_stmt = $conn->prepare($insert_sql);
        if (!$insert_stmt) {
            throw new Exception("Error preparando inserción: " . $conn->error);
        }

        // CORREGIDO: Cadena de tipos con 23 caracteres para 23 parámetros
        // s s s i s s s s i i i s d d d d s s s s s i i
        $insert_stmt->bind_param(
            "sssissssiiisddddsssssii",
            $sku,              // s - string
            $name,             // s - string  
            $description,      // s - string
            $category_id,      // i - integer
            $item_type,        // s - string
            $brand,            // s - string
            $model,            // s - string
            $part_number,      // s - string
            $current_stock,    // i - integer
            $minimum_stock,    // i - integer
            $maximum_stock,    // i - integer
            $unit_of_measure,  // s - string
            $initial_cost,     // d - double (NUEVO)
            $unit_cost,        // d - double (Precio Venta)
            $initial_cost,     // d - double (Average Cost = Costo Compra)
            $initial_cost,     // d - double (Last Cost = Costo Compra)
            $location,         // s - string
            $shelf,            // s - string
            $bin,              // s - string
            $barcode,          // s - string
            $qr_code,          // s - string
            $supplier_id,      // i - integer
            $created_by        // i - integer
        );

        if (!$insert_stmt->execute()) {
            throw new Exception("Error al insertar el item: " . $insert_stmt->error);
        }

        $item_id = $conn->insert_id;
        $insert_stmt->close();

        // === CREAR MOVIMIENTO INICIAL SI HAY STOCK ===
        $initial_movement_created = false;
        if ($current_stock > 0) {
            // Verificar si la tabla inventory_movements existe
            $table_check = $conn->query("SHOW TABLES LIKE 'inventory_movements'");

            if ($table_check && $table_check->num_rows > 0) {
                $movement_sql = "INSERT INTO inventory_movements (
                    inventory_item_id, movement_type, movement_reason,
                    quantity, previous_stock, new_stock, unit_cost, total_cost,
                    notes, created_by
                ) VALUES (?, 'entrada', 'ajuste_inventario', ?, 0, ?, ?, ?, 'Stock inicial al crear el item', ?)";

                // Usar initial_cost (Costo Compra) para el movimiento si es > 0, sino usar unit_cost (Precio Venta) como fallback
                // Idealmente siempre debería ser el costo real
                $movement_cost = $initial_cost > 0 ? $initial_cost : $unit_cost;
                $total_cost = $current_stock * $movement_cost;
                $movement_stmt = $conn->prepare($movement_sql);

                if ($movement_stmt) {
                    $movement_stmt->bind_param(
                        "iiiddi",
                        $item_id,
                        $current_stock,
                        $current_stock,
                        $movement_cost,
                        $total_cost,
                        $created_by
                    );

                    if ($movement_stmt->execute()) {
                        $initial_movement_created = true;
                    }
                    $movement_stmt->close();
                }
            }
        }

        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();

        // === OBTENER ITEM CREADO CON INFORMACIÓN COMPLETA ===
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
        $created_item = $get_result->fetch_assoc();
        $get_item_stmt->close();

        if (!$created_item) {
            throw new Exception("No se pudo obtener el item creado");
        }

        // === FORMATEAR DATOS DEL ITEM CREADO ===
        $created_item['id'] = intval($created_item['id']);
        $created_item['current_stock'] = intval($created_item['current_stock']);
        $created_item['minimum_stock'] = intval($created_item['minimum_stock']);
        $created_item['maximum_stock'] = intval($created_item['maximum_stock']);
        $created_item['unit_cost'] = floatval($created_item['unit_cost']);
        $created_item['initial_cost'] = floatval($created_item['initial_cost']);
        $created_item['average_cost'] = floatval($created_item['average_cost']);
        $created_item['last_cost'] = floatval($created_item['last_cost']);
        $created_item['is_active'] = boolval($created_item['is_active']);
        $created_item['category_id'] = $created_item['category_id'] ? intval($created_item['category_id']) : null;
        $created_item['supplier_id'] = $created_item['supplier_id'] ? intval($created_item['supplier_id']) : null;
        $created_item['created_by'] = $created_item['created_by'] ? intval($created_item['created_by']) : null;

        // === INFORMACIÓN ADICIONAL ===
        $item_info = [
            'has_stock' => $created_item['current_stock'] > 0,
            'stock_status' => $created_item['current_stock'] == 0 ? 'sin_stock' : ($created_item['current_stock'] <= $created_item['minimum_stock'] ? 'stock_bajo' : 'stock_normal'),
            'is_complete' => !empty($created_item['category_id']) && !empty($created_item['supplier_id']),
            'estimated_value' => $created_item['current_stock'] * $created_item['unit_cost']
        ];

        // === RESPUESTA EXITOSA ===
        http_response_code(201);
        echo json_encode([
            'success' => true,
            'message' => 'Item de inventario creado exitosamente',
            'data' => [
                'item' => $created_item,
                'item_info' => $item_info,
                'initial_movement_created' => $initial_movement_created
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
