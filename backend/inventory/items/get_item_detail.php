<?php

/**
 * GET /API_Infoapp/inventory/items/get_item_detail.php
 * 
 * Endpoint para obtener información detallada de un item específico de inventario
 * Incluye historial de movimientos, estadísticas y datos relacionados
 * 
 * Parámetros requeridos:
 * - id: int (ID del item) O sku: string (SKU del item)
 * 
 * Parámetros opcionales:
 * - include_movements: boolean (incluir historial de movimientos, default: true)
 * - movements_limit: int (límite de movimientos a incluir, default: 10)
 * - include_services: boolean (incluir servicios relacionados, default: true)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/get_item_detail.php', 'view_item_detail');

header('Content-Type: application/json');

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde items/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    // Obtener parámetros
    $item_id = isset($_GET['id']) ? intval($_GET['id']) : null;
    $sku = isset($_GET['sku']) ? trim($_GET['sku']) : '';
    $include_movements = isset($_GET['include_movements']) ? filter_var($_GET['include_movements'], FILTER_VALIDATE_BOOLEAN) : true;
    $movements_limit = isset($_GET['movements_limit']) ? max(1, min(50, intval($_GET['movements_limit']))) : 10;
    $include_services = isset($_GET['include_services']) ? filter_var($_GET['include_services'], FILTER_VALIDATE_BOOLEAN) : true;

    // Validar que se proporcione al menos un identificador
    if (!$item_id && empty($sku)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Se requiere proporcionar el ID o SKU del item',
            'errors' => ['identifier' => 'Debe proporcionar el parámetro "id" o "sku"']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // Consulta principal para obtener el item
    $item_sql = "SELECT 
                    ii.id,
                    ii.sku,
                    ii.name,
                    ii.description,
                    ii.category_id,
                    ic.name as category_name,
                    ic.description as category_description,
                    ii.item_type,
                    ii.brand,
                    ii.model,
                    ii.part_number,
                    ii.current_stock,
                    ii.minimum_stock,
                    ii.maximum_stock,
                    ii.unit_of_measure,
                    ii.initial_cost,
                    ii.unit_cost,
                    ii.average_cost,
                    ii.last_cost,
                    ii.location,
                    ii.shelf,
                    ii.bin,
                    ii.barcode,
                    ii.qr_code,
                    ii.supplier_id,
                    s.name as supplier_name,
                    s.contact_person as supplier_contact,
                    s.email as supplier_email,
                    s.phone as supplier_phone,
                    ii.is_active,
                    ii.created_by,
                    ii.created_at,
                    ii.updated_at,
                    -- Calcular valor total del stock
                    (ii.current_stock * ii.unit_cost) as stock_value,
                    -- Determinar si tiene stock bajo
                    CASE 
                        WHEN ii.current_stock <= ii.minimum_stock AND ii.minimum_stock > 0 THEN 1 
                        ELSE 0 
                    END as is_low_stock
                FROM inventory_items ii
                LEFT JOIN inventory_categories ic ON ii.category_id = ic.id
                LEFT JOIN suppliers s ON ii.supplier_id = s.id
                WHERE ";

    // Construir condición WHERE y ejecutar consulta
    if ($item_id) {
        $item_sql .= "ii.id = ?";
        $item_stmt = $conn->prepare($item_sql);
        $item_stmt->bind_param("i", $item_id);
    } else {
        $item_sql .= "ii.sku = ?";
        $item_stmt = $conn->prepare($item_sql);
        $item_stmt->bind_param("s", $sku);
    }

    $item_stmt->execute();
    $item_result = $item_stmt->get_result();
    $item = $item_result->fetch_assoc();

    // Verificar que el item existe
    if (!$item) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Item no encontrado',
            'errors' => ['item' => 'El item especificado no existe en el sistema']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // Formatear datos del item
    $item['id'] = intval($item['id']);
    $item['current_stock'] = intval($item['current_stock']);
    $item['minimum_stock'] = intval($item['minimum_stock']);
    $item['maximum_stock'] = intval($item['maximum_stock']);
    $item['unit_cost'] = floatval($item['unit_cost']);
    $item['initial_cost'] = floatval($item['initial_cost']);
    $item['average_cost'] = floatval($item['average_cost']);
    $item['last_cost'] = floatval($item['last_cost']);
    $item['stock_value'] = floatval($item['stock_value']);
    $item['is_low_stock'] = boolval($item['is_low_stock']);
    $item['is_active'] = boolval($item['is_active']);
    $item['category_id'] = $item['category_id'] ? intval($item['category_id']) : null;
    $item['supplier_id'] = $item['supplier_id'] ? intval($item['supplier_id']) : null;
    $item['created_by'] = $item['created_by'] ? intval($item['created_by']) : null;

    // Obtener estadísticas de movimientos
    $stats_sql = "SELECT 
                    COUNT(*) as total_movements,
                    SUM(CASE WHEN movement_type = 'entrada' THEN quantity ELSE 0 END) as total_entries,
                    SUM(CASE WHEN movement_type = 'salida' THEN quantity ELSE 0 END) as total_exits,
                    SUM(CASE WHEN movement_type = 'ajuste' THEN quantity ELSE 0 END) as total_adjustments,
                    MAX(created_at) as last_movement_date,
                    MIN(created_at) as first_movement_date
                  FROM inventory_movements 
                  WHERE inventory_item_id = ?";

    $stats_stmt = $conn->prepare($stats_sql);
    $stats_stmt->bind_param("i", $item['id']);
    $stats_stmt->execute();
    $stats_result = $stats_stmt->get_result();
    $movement_stats = $stats_result->fetch_assoc();

    // Formatear estadísticas
    $movement_stats['total_movements'] = intval($movement_stats['total_movements']);
    $movement_stats['total_entries'] = intval($movement_stats['total_entries']);
    $movement_stats['total_exits'] = intval($movement_stats['total_exits']);
    $movement_stats['total_adjustments'] = intval($movement_stats['total_adjustments']);

    $response_data = [
        'item' => $item,
        'movement_stats' => $movement_stats
    ];

    // Incluir historial de movimientos si se solicita
    if ($include_movements) {
        $movements_sql = "SELECT 
                            im.id,
                            im.movement_type,
                            im.movement_reason,
                            im.quantity,
                            im.previous_stock,
                            im.new_stock,
                            im.unit_cost,
                            im.total_cost,
                            im.reference_type,
                            im.reference_id,
                            im.notes,
                            im.document_number,
                            im.created_by,
                            im.created_at
                          FROM inventory_movements im
                          WHERE im.inventory_item_id = ?
                          ORDER BY im.created_at DESC
                          LIMIT ?";

        $movements_stmt = $conn->prepare($movements_sql);
        $movements_stmt->bind_param("ii", $item['id'], $movements_limit);
        $movements_stmt->execute();
        $movements_result = $movements_stmt->get_result();

        $movements = [];
        while ($movement = $movements_result->fetch_assoc()) {
            // Formatear movimientos
            $movement['id'] = intval($movement['id']);
            $movement['quantity'] = intval($movement['quantity']);
            $movement['previous_stock'] = intval($movement['previous_stock']);
            $movement['new_stock'] = intval($movement['new_stock']);
            $movement['unit_cost'] = floatval($movement['unit_cost']);
            $movement['total_cost'] = floatval($movement['total_cost']);
            $movement['reference_id'] = $movement['reference_id'] ? intval($movement['reference_id']) : null;
            $movement['created_by'] = $movement['created_by'] ? intval($movement['created_by']) : null;

            $movements[] = $movement;
        }

        $response_data['recent_movements'] = $movements;
    }

    // Incluir servicios relacionados si se solicita
    if ($include_services) {
        $services_sql = "SELECT 
                            s.id as service_id,
                            s.orden_cliente,
                            s.fecha_registro,
                            sii.quantity_used,
                            sii.unit_cost as service_unit_cost,
                            sii.total_cost as service_total_cost,
                            sii.created_at as usage_date
                         FROM service_inventory_items sii
                         INNER JOIN servicios s ON sii.service_id = s.id
                         WHERE sii.inventory_item_id = ?
                         ORDER BY sii.created_at DESC
                         LIMIT 10";

        $services_stmt = $conn->prepare($services_sql);
        $services_stmt->bind_param("i", $item['id']);
        $services_stmt->execute();
        $services_result = $services_stmt->get_result();

        $related_services = [];
        while ($service = $services_result->fetch_assoc()) {
            // Formatear servicios relacionados
            $service['service_id'] = intval($service['service_id']);
            $service['quantity_used'] = intval($service['quantity_used']);
            $service['service_unit_cost'] = floatval($service['service_unit_cost']);
            $service['service_total_cost'] = floatval($service['service_total_cost']);

            $related_services[] = $service;
        }

        $response_data['related_services'] = $related_services;
        $response_data['services_count'] = count($related_services);
    }

    // Calcular alertas y recomendaciones
    $alerts = [];
    $recommendations = [];

    if ($item['is_low_stock']) {
        $alerts[] = [
            'type' => 'warning',
            'message' => 'Stock bajo: cantidad actual (' . $item['current_stock'] . ') está por debajo del mínimo (' . $item['minimum_stock'] . ')',
            'priority' => 'high'
        ];
        $recommendations[] = 'Considere realizar una orden de compra para reponer el stock';
    }

    if ($item['current_stock'] == 0) {
        $alerts[] = [
            'type' => 'error',
            'message' => 'Sin stock disponible',
            'priority' => 'critical'
        ];
        $recommendations[] = 'Compra urgente requerida para evitar interrupciones en el servicio';
    }

    if ($item['maximum_stock'] > 0 && $item['current_stock'] > $item['maximum_stock']) {
        $alerts[] = [
            'type' => 'info',
            'message' => 'Stock excede el máximo recomendado',
            'priority' => 'low'
        ];
        $recommendations[] = 'Evaluar uso del exceso de inventario o ajustar máximos';
    }

    $response_data['alerts'] = $alerts;
    $response_data['recommendations'] = $recommendations;

    // Respuesta exitosa
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Detalle del item obtenido exitosamente',
        'data' => $response_data
    ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    // Error general
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()]
    ], JSON_UNESCAPED_UNICODE);
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}

/**
 * Ejemplos de uso:
 * 
 * GET /API_Infoapp/inventory/items/get_item_detail.php?id=1
 * GET /API_Infoapp/inventory/items/get_item_detail.php?sku=REP001
 * GET /API_Infoapp/inventory/items/get_item_detail.php?id=1&include_movements=false
 * GET /API_Infoapp/inventory/items/get_item_detail.php?id=1&movements_limit=20
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Detalle del item obtenido exitosamente",
 *   "data": {
 *     "item": {
 *       "id": 1,
 *       "sku": "REP001",
 *       "name": "Filtro de Aceite",
 *       "description": "Filtro de aceite para motor",
 *       "category_id": 1,
 *       "category_name": "Repuestos Mecánicos",
 *       "category_description": "Repuestos para mantenimiento mecánico",
 *       "item_type": "repuesto",
 *       "brand": "Mann Filter",
 *       "model": "W920/21",
 *       "part_number": "MF-W920/21",
 *       "current_stock": 25,
 *       "minimum_stock": 5,
 *       "maximum_stock": 100,
 *       "unit_of_measure": "unidad",
 *       "unit_cost": 15.50,
 *       "average_cost": 15.50,
 *       "last_cost": 15.50,
 *       "location": "Almacén A",
 *       "shelf": "A1",
 *       "bin": "B10",
 *       "barcode": "1234567890",
 *       "supplier_id": 1,
 *       "supplier_name": "Repuestos SA",
 *       "supplier_contact": "Juan Pérez",
 *       "supplier_email": "juan@repuestos.com",
 *       "supplier_phone": "555-1234",
 *       "is_active": true,
 *       "created_by": 1,
 *       "created_at": "2025-01-15 10:30:00",
 *       "updated_at": "2025-01-15 10:30:00",
 *       "stock_value": 387.50,
 *       "is_low_stock": false
 *     },
 *     "movement_stats": {
 *       "total_movements": 5,
 *       "total_entries": 50,
 *       "total_exits": 25,
 *       "total_adjustments": 0,
 *       "last_movement_date": "2025-01-15 14:20:00",
 *       "first_movement_date": "2025-01-15 10:30:00"
 *     },
 *     "recent_movements": [
 *       {
 *         "id": 5,
 *         "movement_type": "salida",
 *         "movement_reason": "uso_servicio",
 *         "quantity": 2,
 *         "previous_stock": 27,
 *         "new_stock": 25,
 *         "unit_cost": 15.50,
 *         "total_cost": 31.00,
 *         "reference_type": "service",
 *         "reference_id": 123,
 *         "notes": "Usado en servicio de mantenimiento",
 *         "document_number": null,
 *         "created_by": 1,
 *         "created_at": "2025-01-15 14:20:00"
 *       }
 *     ],
 *     "related_services": [
 *       {
 *         "service_id": 123,
 *         "orden_cliente": "ORD-2025-001",
 *         "fecha_registro": "2025-01-15 14:00:00",
 *         "quantity_used": 2,
 *         "service_unit_cost": 15.50,
 *         "service_total_cost": 31.00,
 *         "usage_date": "2025-01-15 14:20:00"
 *       }
 *     ],
 *     "services_count": 1,
 *     "alerts": [],
 *     "recommendations": []
 *   }
 * }
 */
