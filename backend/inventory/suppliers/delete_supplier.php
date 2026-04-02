<?php
/**
 * DELETE /api/inventory/suppliers/delete_supplier.php
 * 
 * Endpoint para eliminar un proveedor de inventario
 * Incluye validaciones de seguridad y verificación de dependencias
 * 
 * Parámetros requeridos:
 * - id: int (ID del proveedor a eliminar)
 * 
 * Parámetros opcionales:
 * - force: boolean (forzar eliminación aunque tenga items asociados, default: false)
 * - soft_delete: boolean (eliminación lógica en lugar de física, default: true)
 * - transfer_items_to: int (ID del proveedor al cual transferir los items, opcional)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

// Solo permitir método DELETE
if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido',
        'errors' => ['method' => 'Solo se permite método DELETE']
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde suppliers/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Obtener datos del cuerpo de la petición o de query parameters
    $input = json_decode(file_get_contents('php://input'), true);
    
    // Si no hay body JSON, intentar obtener desde query parameters
    if (!$input) {
        $input = $_GET;
    }
    
    if (empty($input)) {
        throw new Exception('No se recibieron parámetros válidos');
    }
    
    // === VALIDACIONES DE PARÁMETROS REQUERIDOS ===
    $errors = [];
    
    // Validar ID (requerido)
    if (!isset($input['id']) || !is_numeric($input['id']) || $input['id'] <= 0) {
        $errors['id'] = 'El ID del proveedor es requerido y debe ser un número válido';
    } else {
        $supplier_id = intval($input['id']);
        
        // Verificar que el proveedor existe
        $check_exists_sql = "SELECT id, name, is_active FROM suppliers WHERE id = ?";
        $check_exists_stmt = $conn->prepare($check_exists_sql);
        $check_exists_stmt->bind_param("i", $supplier_id);
        $check_exists_stmt->execute();
        $check_exists_result = $check_exists_stmt->get_result();
        $supplier_data = $check_exists_result->fetch_assoc();
        
        if (!$supplier_data) {
            $errors['id'] = "No existe un proveedor con el ID {$supplier_id}";
        }
    }
    
    // Parámetros opcionales
    $force_delete = isset($input['force']) ? filter_var($input['force'], FILTER_VALIDATE_BOOLEAN) : false;
    $soft_delete = isset($input['soft_delete']) ? filter_var($input['soft_delete'], FILTER_VALIDATE_BOOLEAN) : true;
    $transfer_items_to = null;
    
    if (isset($input['transfer_items_to']) && is_numeric($input['transfer_items_to']) && $input['transfer_items_to'] > 0) {
        $transfer_items_to = intval($input['transfer_items_to']);
        
        // Verificar que el proveedor de destino existe y está activo
        if ($transfer_items_to !== $supplier_id) {
            $check_target_sql = "SELECT COUNT(*) as count FROM suppliers WHERE id = ? AND is_active = 1";
            $check_target_stmt = $conn->prepare($check_target_sql);
            $check_target_stmt->bind_param("i", $transfer_items_to);
            $check_target_stmt->execute();
            $check_target_result = $check_target_stmt->get_result();
            
            if ($check_target_result->fetch_assoc()['count'] == 0) {
                $errors['transfer_items_to'] = "El proveedor de destino con ID {$transfer_items_to} no existe o no está activo";
            }
        } else {
            $errors['transfer_items_to'] = "No se puede transferir a sí mismo";
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
    
    // === VERIFICAR DEPENDENCIAS ===
    
    // Contar items asociados al proveedor
    $count_items_sql = "SELECT COUNT(*) as items_count FROM inventory_items WHERE supplier_id = ? AND is_active = 1";
    $count_items_stmt = $conn->prepare($count_items_sql);
    $count_items_stmt->bind_param("i", $supplier_id);
    $count_items_stmt->execute();
    $count_items_result = $count_items_stmt->get_result();
    $items_count = $count_items_result->fetch_assoc()['items_count'];
    
    // Obtener detalles de los items asociados para el reporte
    $items_details = [];
    if ($items_count > 0) {
        $get_items_sql = "SELECT id, sku, name, current_stock, unit_cost 
                         FROM inventory_items 
                         WHERE supplier_id = ? AND is_active = 1 
                         ORDER BY name 
                         LIMIT 10"; // Limitar para no sobrecargar la respuesta
        $get_items_stmt = $conn->prepare($get_items_sql);
        $get_items_stmt->bind_param("i", $supplier_id);
        $get_items_stmt->execute();
        $get_items_result = $get_items_stmt->get_result();
        
        while ($item = $get_items_result->fetch_assoc()) {
            $items_details[] = [
                'id' => intval($item['id']),
                'sku' => $item['sku'],
                'name' => $item['name'],
                'current_stock' => intval($item['current_stock']),
                'unit_cost' => floatval($item['unit_cost'])
            ];
        }
    }
    
    // Si hay items asociados y no se fuerza la eliminación
    if ($items_count > 0 && !$force_delete && $transfer_items_to === null) {
        http_response_code(409); // Conflict
        echo json_encode([
            'success' => false,
            'message' => 'No se puede eliminar el proveedor porque tiene items asociados',
            'errors' => [
                'dependencies' => "El proveedor tiene {$items_count} items asociados"
            ],
            'data' => [
                'supplier' => $supplier_data,
                'items_count' => $items_count,
                'sample_items' => $items_details,
                'has_more_items' => $items_count > 10,
                'recommendations' => [
                    'transfer_items' => 'Transfiere los items a otro proveedor usando el parámetro transfer_items_to',
                    'force_delete' => 'Usa force=true para eliminar forzadamente (los items quedarán sin proveedor)',
                    'soft_delete' => 'Desactiva el proveedor en lugar de eliminarlo'
                ]
            ]
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);
    
    try {
        $deletion_summary = [
            'supplier_id' => $supplier_id,
            'supplier_name' => $supplier_data['name'],
            'deletion_type' => $soft_delete ? 'soft' : 'hard',
            'items_affected' => $items_count,
            'items_transferred' => 0,
            'items_orphaned' => 0
        ];
        
        // === MANEJAR ITEMS ASOCIADOS ===
        if ($items_count > 0) {
            if ($transfer_items_to !== null) {
                // Transferir items a otro proveedor
                $transfer_sql = "UPDATE inventory_items SET supplier_id = ?, updated_at = NOW() WHERE supplier_id = ? AND is_active = 1";
                $transfer_stmt = $conn->prepare($transfer_sql);
                $transfer_stmt->bind_param("ii", $transfer_items_to, $supplier_id);
                $transfer_result = $transfer_stmt->execute();
                
                if (!$transfer_result) {
                    throw new Exception('Error al transferir los items al nuevo proveedor');
                }
                
                $deletion_summary['items_transferred'] = $transfer_stmt->affected_rows;
                $deletion_summary['transferred_to'] = $transfer_items_to;
                
            } elseif ($force_delete) {
                // Dejar los items sin proveedor (orphan)
                $orphan_sql = "UPDATE inventory_items SET supplier_id = NULL, updated_at = NOW() WHERE supplier_id = ? AND is_active = 1";
                $orphan_stmt = $conn->prepare($orphan_sql);
                $orphan_stmt->bind_param("i", $supplier_id);
                $orphan_result = $orphan_stmt->execute();
                
                if (!$orphan_result) {
                    throw new Exception('Error al desvincular los items del proveedor');
                }
                
                $deletion_summary['items_orphaned'] = $orphan_stmt->affected_rows;
            }
        }
        
        // === ELIMINAR O DESACTIVAR PROVEEDOR ===
        if ($soft_delete) {
            // Eliminación lógica: desactivar proveedor
            $delete_sql = "UPDATE suppliers SET is_active = 0, updated_at = NOW() WHERE id = ?";
            $delete_stmt = $conn->prepare($delete_sql);
            $delete_stmt->bind_param("i", $supplier_id);
            $delete_result = $delete_stmt->execute();
            
            if (!$delete_result) {
                throw new Exception('Error al desactivar el proveedor');
            }
            
            $deletion_summary['deletion_type'] = 'soft';
            $message = 'Proveedor desactivado exitosamente';
            
        } else {
            // Eliminación física: eliminar proveedor de la base de datos
            $delete_sql = "DELETE FROM suppliers WHERE id = ?";
            $delete_stmt = $conn->prepare($delete_sql);
            $delete_stmt->bind_param("i", $supplier_id);
            $delete_result = $delete_stmt->execute();
            
            if (!$delete_result) {
                throw new Exception('Error al eliminar el proveedor');
            }
            
            if ($delete_stmt->affected_rows === 0) {
                throw new Exception('No se eliminó ningún registro. El proveedor podría no existir');
            }
            
            $deletion_summary['deletion_type'] = 'hard';
            $message = 'Proveedor eliminado exitosamente';
        }
        
        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();
        
        // === RESPUESTA EXITOSA ===
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => $message,
            'data' => [
                'deletion_summary' => $deletion_summary,
                'affected_items' => $items_details
            ]
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        // Revertir transacción en caso de error
        $conn->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    // Error general
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
}

// Restaurar autocommit y cerrar conexión
if (isset($conn)) {
    $conn->autocommit(true);
    $conn->close();
}

/**
 * Ejemplos de uso:
 * 
 * // Eliminación simple (soft delete por defecto)
 * DELETE /api/inventory/suppliers/delete_supplier.php
 * {
 *   "id": 1
 * }
 * 
 * // Eliminación física (hard delete)
 * DELETE /api/inventory/suppliers/delete_supplier.php
 * {
 *   "id": 2,
 *   "soft_delete": false,
 *   "force": true
 * }
 * 
 * // Transferir items a otro proveedor antes de eliminar
 * DELETE /api/inventory/suppliers/delete_supplier.php
 * {
 *   "id": 3,
 *   "transfer_items_to": 1,
 *   "soft_delete": false
 * }
 * 
 * // Usando query parameters en lugar de body JSON
 * DELETE /api/inventory/suppliers/delete_supplier.php?id=4&force=true
 * 
 * Ejemplo de respuesta exitosa:
 * 
 * {
 *   "success": true,
 *   "message": "Proveedor desactivado exitosamente",
 *   "data": {
 *     "deletion_summary": {
 *       "supplier_id": 1,
 *       "supplier_name": "Proveedor Ejemplo",
 *       "deletion_type": "soft",
 *       "items_affected": 5,
 *       "items_transferred": 0,
 *       "items_orphaned": 0
 *     },
 *     "affected_items": [
 *       {
 *         "id": 10,
 *         "sku": "FIL-001",
 *         "name": "Filtro de aire",
 *         "current_stock": 15,
 *         "unit_cost": 25.50
 *       }
 *     ]
 *   }
 * }
 * 
 * Ejemplo de respuesta con conflicto (items asociados):
 * 
 * {
 *   "success": false,
 *   "message": "No se puede eliminar el proveedor porque tiene items asociados",
 *   "errors": {
 *     "dependencies": "El proveedor tiene 3 items asociados"
 *   },
 *   "data": {
 *     "supplier": {
 *       "id": 1,
 *       "name": "Proveedor con Items",
 *       "is_active": "1"
 *     },
 *     "items_count": 3,
 *     "sample_items": [...],
 *     "has_more_items": false,
 *     "recommendations": {
 *       "transfer_items": "Transfiere los items a otro proveedor usando el parámetro transfer_items_to",
 *       "force_delete": "Usa force=true para eliminar forzadamente (los items quedarán sin proveedor)",
 *       "soft_delete": "Desactiva el proveedor en lugar de eliminarlo"
 *     }
 *   }
 * }
 */
?>