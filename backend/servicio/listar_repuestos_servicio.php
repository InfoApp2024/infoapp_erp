<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/servicio_repuestos/listar_repuestos_servicio.php', 'view_service_inventory');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Validar parámetros requeridos
    if (!isset($_GET['servicio_id']) || empty($_GET['servicio_id'])) {
        sendJsonResponse(errorResponse('Parámetro requerido: servicio_id'), 400);
    }

    $servicioId = (int) $_GET['servicio_id'];
    $incluirDetallesItem = isset($_GET['incluir_detalles_item']) ? filter_var($_GET['incluir_detalles_item'], FILTER_VALIDATE_BOOLEAN) : true;

    if ($servicioId <= 0) {
        sendJsonResponse(errorResponse('ID de servicio inválido'), 400);
    }

    // PASO 5: Conexión a BD
    require '../conexion.php';

    // PASO 6: Verificar que el servicio existe
    $stmtCheckService = $conn->prepare("
        SELECT s.id, s.o_servicio, s.suministraron_repuestos, s.anular_servicio,
               e.nombre_estado as estado_nombre
        FROM servicios s
        LEFT JOIN estados_proceso e ON s.estado = e.id
        WHERE s.id = ?
    ");
    $stmtCheckService->bind_param("i", $servicioId);
    $stmtCheckService->execute();
    $serviceResult = $stmtCheckService->get_result();

    if ($serviceResult->num_rows === 0) {
        sendJsonResponse(errorResponse('Servicio no encontrado'), 404);
    }

    $servicio = $serviceResult->fetch_assoc();

    // PASO 7: Construir query principal
    if ($incluirDetallesItem) {
        // Query completa con detalles del item
        $sqlRepuestos = "SELECT 
                    sr.id,
                    sr.servicio_id,
                    sr.inventory_item_id,
                    sr.cantidad,
                    sr.costo_unitario,
                    sr.notas,
                    sr.usuario_asigno,
                    sr.fecha_asignacion,
                    (sr.cantidad * sr.costo_unitario) as costo_total,
                    
                    -- Detalles del item de inventario
                    i.sku as item_sku,
                    i.name as item_nombre,
                    i.description as item_descripcion,
                    i.brand as item_marca,
                    i.model as item_modelo,
                    i.part_number as item_part_number,
                    i.current_stock as item_stock_actual,
                    i.minimum_stock as item_stock_minimo,
                    i.unit_of_measure as item_unidad_medida,
                    i.location as item_ubicacion,
                    i.shelf as item_shelf,
                    i.bin as item_bin,
                    
                    -- Información de categoría
                    c.name as item_categoria,
                    
                    -- Información de proveedor
                    s.name as item_proveedor,
                    
                    -- Usuario que asignó
                    u.NOMBRE_USER as usuario_asigno_nombre,
                    
                    -- Información de Operación (NUEVO)
                    sr.operacion_id,
                    o.descripcion as operacion_nombre,
                    o.is_master
                    
                FROM servicio_repuestos sr
                INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
                LEFT JOIN inventory_categories c ON i.category_id = c.id
                LEFT JOIN suppliers s ON i.supplier_id = s.id
                LEFT JOIN usuarios u ON sr.usuario_asigno = u.id
                LEFT JOIN operaciones o ON sr.operacion_id = o.id
                WHERE sr.servicio_id = ?
                ORDER BY sr.fecha_asignacion DESC";
    } else {
        // Query simple sin detalles del item
        $sqlRepuestos = "SELECT 
                    sr.id,
                    sr.servicio_id,
                    sr.inventory_item_id,
                    sr.cantidad,
                    sr.costo_unitario,
                    sr.notas,
                    sr.usuario_asigno,
                    sr.fecha_asignacion,
                    (sr.cantidad * sr.costo_unitario) as costo_total
                FROM servicio_repuestos sr
                WHERE sr.servicio_id = ?
                ORDER BY sr.fecha_asignacion DESC";
    }

    // PASO 8: Ejecutar query
    $stmt = $conn->prepare($sqlRepuestos);
    $stmt->bind_param("i", $servicioId);

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query de repuestos: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $repuestos = [];
    $costoTotal = 0.0;
    $cantidadTotal = 0;

    while ($row = $result->fetch_assoc()) {
        $repuesto = [
            // Campos básicos de la relación
            'id' => (int) $row['id'],
            'servicio_id' => (int) $row['servicio_id'],
            'inventory_item_id' => (int) $row['inventory_item_id'],
            'cantidad' => (float) $row['cantidad'], // Corregido: float para decimales
            'cantidad_decimal' => (float) $row['cantidad'], // Asegurar campo decimal explícito
            'costo_unitario' => (float) $row['costo_unitario'],
            'costo_total' => (float) $row['costo_total'],
            'notas' => $row['notas'],
            'usuario_asigno' => $row['usuario_asigno'] ? (int) $row['usuario_asigno'] : null,
            'fecha_asignacion' => $row['fecha_asignacion'],
            // Campos de Operación
            'operacion_id' => isset($row['operacion_id']) ? (int) $row['operacion_id'] : null,
            'operacion_nombre' => $row['operacion_nombre'] ?? null,
            'is_master' => isset($row['is_master']) ? (bool) $row['is_master'] : false
        ];

        // Si se incluyen detalles del item
        if ($incluirDetallesItem) {
            $repuesto = array_merge($repuesto, [
                // Información del item
                'item_sku' => $row['item_sku'],
                'item_nombre' => $row['item_nombre'],
                'item_descripcion' => $row['item_descripcion'],
                'item_marca' => $row['item_marca'],
                'item_modelo' => $row['item_modelo'],
                'item_part_number' => $row['item_part_number'],
                'item_stock_actual' => $row['item_stock_actual'] ? (int) $row['item_stock_actual'] : 0,
                'item_stock_minimo' => $row['item_stock_minimo'] ? (int) $row['item_stock_minimo'] : 0,
                'item_unidad_medida' => $row['item_unidad_medida'] ?? 'unidad',
                'item_ubicacion' => $row['item_ubicacion'],
                'item_shelf' => $row['item_shelf'],
                'item_bin' => $row['item_bin'],
                'item_categoria' => $row['item_categoria'],
                'item_proveedor' => $row['item_proveedor'],
                'usuario_asigno_nombre' => $row['usuario_asigno_nombre'],

                // Campos calculados
                'item_ubicacion_completa' => buildItemLocation($row['item_ubicacion'], $row['item_shelf'], $row['item_bin']),
                'item_nombre_completo' => buildItemFullName($row['item_nombre'], $row['item_marca'], $row['item_modelo']),
                'item_tiene_stock_bajo' => checkLowStock($row['item_stock_actual'], $row['item_stock_minimo']),
                'item_info_stock' => buildStockInfo($row['item_stock_actual'], $row['item_stock_minimo'], $row['item_unidad_medida'])
            ]);
        }

        $repuestos[] = $repuesto;
        $costoTotal += (float) $row['costo_total'];
        $cantidadTotal += (float) $row['cantidad']; // Corregido: float para suma decimal
    }

    // PASO 9: Obtener estadísticas adicionales si hay repuestos
    $estadisticas = [];
    if (!empty($repuestos)) {
        // Contar por categorías
        $stmtStats = $conn->prepare("
            SELECT 
                c.name as categoria,
                COUNT(*) as items,
                SUM(sr.cantidad) as cantidad_total,
                SUM(sr.cantidad * sr.costo_unitario) as valor_total
            FROM servicio_repuestos sr
            INNER JOIN inventory_items i ON sr.inventory_item_id = i.id
            LEFT JOIN inventory_categories c ON i.category_id = c.id
            WHERE sr.servicio_id = ?
            GROUP BY c.id, c.name
            ORDER BY valor_total DESC
        ");
        $stmtStats->bind_param("i", $servicioId);
        $stmtStats->execute();
        $statsResult = $stmtStats->get_result();

        $porCategorias = [];
        while ($statRow = $statsResult->fetch_assoc()) {
            $porCategorias[] = [
                'categoria' => $statRow['categoria'] ?? 'Sin categoría',
                'items' => (int) $statRow['items'],
                'cantidad_total' => (int) $statRow['cantidad_total'],
                'valor_total' => (float) $statRow['valor_total']
            ];
        }

        $estadisticas = [
            'por_categorias' => $porCategorias,
            'item_mas_costoso' => !empty($repuestos) ? max(array_column($repuestos, 'costo_total')) : 0,
            'item_menos_costoso' => !empty($repuestos) ? min(array_column($repuestos, 'costo_total')) : 0,
            'costo_promedio' => count($repuestos) > 0 ? $costoTotal / count($repuestos) : 0
        ];
    }

    // PASO 10: Preparar respuesta
    $response = [
        'success' => true,
        'data' => [
            'repuestos' => $repuestos,
            'servicio_info' => [
                'id' => (int) $servicio['id'],
                'numero_servicio' => (int) $servicio['o_servicio'],
                'suministraron_repuestos' => (int) $servicio['suministraron_repuestos'] === 1,
                'esta_anulado' => (int) $servicio['anular_servicio'] === 1,
                'estado_nombre' => $servicio['estado_nombre']
            ],
            'resumen' => [
                'total_items' => count($repuestos),
                'cantidad_total' => $cantidadTotal,
                'costo_total' => round($costoTotal, 2),
                'tiene_repuestos' => count($repuestos) > 0,
                'incluir_detalles_item' => $incluirDetallesItem
            ]
        ],
        'message' => count($repuestos) > 0
            ? "Servicio #{$servicio['o_servicio']}: " . count($repuestos) . " repuestos asignados por un valor total de $" . number_format($costoTotal, 2)
            : "Servicio #{$servicio['o_servicio']}: No tiene repuestos asignados",
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ];

    // Agregar estadísticas si las hay
    if (!empty($estadisticas)) {
        $response['data']['estadisticas'] = $estadisticas;
    }

    sendJsonResponse($response);
} catch (Exception $e) {
    error_log("Error en listar_repuestos_servicio.php: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error obteniendo repuestos del servicio: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}

// FUNCIONES AUXILIARES

function buildItemLocation($location, $shelf, $bin)
{
    $parts = [];
    if (!empty($location))
        $parts[] = $location;
    if (!empty($shelf))
        $parts[] = "Estante: $shelf";
    if (!empty($bin))
        $parts[] = "Bin: $bin";
    return !empty($parts) ? implode(' - ', $parts) : 'Ubicación no definida';
}

function buildItemFullName($name, $brand, $model)
{
    $fullName = $name ?? 'Item sin nombre';
    if (!empty($brand) && !empty($model)) {
        $fullName .= " ($brand - $model)";
    } elseif (!empty($brand)) {
        $fullName .= " ($brand)";
    } elseif (!empty($model)) {
        $fullName .= " - $model";
    }
    return $fullName;
}

function checkLowStock($currentStock, $minimumStock)
{
    if ($minimumStock === null || $minimumStock <= 0)
        return false;
    return (int) $currentStock <= (int) $minimumStock;
}

function buildStockInfo($currentStock, $minimumStock, $unitOfMeasure)
{
    $stock = (int) $currentStock;
    $unit = $unitOfMeasure ?? 'und';
    $stockText = "$stock $unit";

    if (checkLowStock($currentStock, $minimumStock)) {
        return "$stockText (STOCK BAJO)";
    }

    return $stockText;
}
