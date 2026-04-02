<?php

/**
 * GET /backend/dashboard/kpi_inventario.php
 * 
 * Endpoint modular para obtener KPIs específicos del módulo de INVENTARIO.
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
header('Content-Type: application/json; charset=utf-8');

require_once '../conexion.php';
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    // Filtros opcionales (por si se quiere filtrar por categoría más adelante)
    $categoryId = isset($_GET['category_id']) ? intval($_GET['category_id']) : null;

    $response = [
        'generado_el' => date('Y-m-d H:i:s')
    ];

    // 1. KPI: Valorización de Inventario (Card Principal)
    // Suma de (Stock Actual * Costo Unitario)
    $sqlValor = "SELECT 
                    SUM(current_stock * unit_cost) as valor_total,
                    COUNT(*) as total_items,
                    SUM(current_stock) as total_unidades
                 FROM inventory_items 
                 WHERE is_active = 1";

    if ($categoryId) {
        $sqlValor .= " AND category_id = $categoryId";
    }

    $result = $conn->query($sqlValor);
    $response['resumen_inventario'] = $result->fetch_assoc();

    // 2. KPI: Top 10 Stock Bajo (Alerta Crítica)
    // Items donde stock actual <= stock mínimo
    $sqlLowStock = "SELECT 
                        name, 
                        sku, 
                        current_stock, 
                        minimum_stock 
                    FROM inventory_items 
                    WHERE current_stock <= minimum_stock 
                    AND is_active = 1 
                    ORDER BY (current_stock - minimum_stock) ASC 
                    LIMIT 10";

    $result = $conn->query($sqlLowStock);
    $response['alertas_stock'] = $result->fetch_all(MYSQLI_ASSOC);

    // 3. KPI: Distribución por Categoría (Pie Chart)
    $sqlCategorias = "SELECT 
                        c.name as label,
                        COUNT(i.id) as value,
                        SUM(i.current_stock * i.unit_cost) as valor_categoria
                      FROM inventory_items i
                      LEFT JOIN inventory_categories c ON i.category_id = c.id
                      WHERE i.is_active = 1
                      GROUP BY i.category_id, c.name
                      ORDER BY value DESC
                      LIMIT 8"; // Top 8 categorías + Otros podría ser lógica frontend

    $result = $conn->query($sqlCategorias);
    $response['distribucion_categorias'] = $result->fetch_all(MYSQLI_ASSOC);

    echo json_encode([
        'success' => true,
        'data' => $response
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
