<?php
/**
 * GET /api/inventory/categories/get_categories.php
 * 
 * Endpoint para obtener todas las categorías de inventario
 * Soporta estructura jerárquica (categorías padre e hijos)
 * 
 * Parámetros opcionales:
 * - include_inactive: boolean (incluir categorías inactivas)
 * - parent_id: int (filtrar por categoría padre)
 * - flat: boolean (devolver lista plana sin jerarquía)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/categories/get_categories.php', 'list_categories');

header('Content-Type: application/json');

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde categories/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }
    
    // Obtener parámetros de la URL
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;
    $parent_id = isset($_GET['parent_id']) ? intval($_GET['parent_id']) : null;
    $flat = isset($_GET['flat']) ? filter_var($_GET['flat'], FILTER_VALIDATE_BOOLEAN) : false;
    
    // === CONSTRUIR CONSULTA SQL ===
    $sql = "SELECT 
                id,
                name,
                description,
                parent_id,
                is_active,
                created_at,
                updated_at,
                (SELECT COUNT(*) FROM inventory_categories ic2 WHERE ic2.parent_id = ic.id) as children_count,
                (SELECT COUNT(*) FROM inventory_items ii WHERE ii.category_id = ic.id AND ii.is_active = 1) as items_count
            FROM inventory_categories ic 
            WHERE 1=1";
    
    $param_types = "";
    $param_values = [];
    
    // === APLICAR FILTROS ===
    
    // Filtro por estado activo/inactivo
    if (!$include_inactive) {
        $sql .= " AND is_active = 1";
    }
    
    // Filtro por categoría padre
    if ($parent_id !== null) {
        $sql .= " AND parent_id = ?";
        $param_types .= "i";
        $param_values[] = $parent_id;
    }
    
    // Ordenar por nombre
    $sql .= " ORDER BY name ASC";
    
    // === EJECUTAR CONSULTA ===
    $stmt = $conn->prepare($sql);
    
    if (!empty($param_values)) {
        $stmt->bind_param($param_types, ...$param_values);
    }
    
    $stmt->execute();
    $result = $stmt->get_result();
    
    $categories = [];
    while ($row = $result->fetch_assoc()) {
        // Formatear datos
        $row['id'] = intval($row['id']);
        $row['parent_id'] = $row['parent_id'] ? intval($row['parent_id']) : null;
        $row['is_active'] = boolval($row['is_active']);
        $row['children_count'] = intval($row['children_count']);
        $row['items_count'] = intval($row['items_count']);
        
        $categories[] = $row;
    }
    
    // === GENERAR ESTRUCTURA JERÁRQUICA ===
    if (!$flat) {
        $categories = buildCategoryTree($categories);
    }
    
    // === CALCULAR ESTADÍSTICAS ===
    $stats = calculateCategoryStats($categories, $flat);
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Categorías obtenidas exitosamente',
        'data' => [
            'categories' => $categories,
            'statistics' => $stats,
            'filters_applied' => [
                'include_inactive' => $include_inactive,
                'parent_id' => $parent_id,
                'flat' => $flat
            ]
        ]
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
 * Función para construir árbol jerárquico de categorías
 * 
 * @param array $categories Lista plana de categorías
 * @param int|null $parent_id ID de la categoría padre (null para raíz)
 * @return array Árbol jerárquico de categorías
 */
function buildCategoryTree($categories, $parent_id = null) {
    $tree = [];
    
    foreach ($categories as $category) {
        // Si la categoría pertenece al nivel actual
        if ($category['parent_id'] == $parent_id) {
            // Buscar hijos recursivamente
            $children = buildCategoryTree($categories, $category['id']);
            
            // Si tiene hijos, agregarlos
            if (!empty($children)) {
                $category['children'] = $children;
                $category['has_children'] = true;
            } else {
                $category['has_children'] = false;
            }
            
            // Calcular nivel de profundidad
            $category['level'] = calculateCategoryLevel($categories, $category['id']);
            
            // Agregar al árbol
            $tree[] = $category;
        }
    }
    
    return $tree;
}

/**
 * Función para calcular el nivel de una categoría en la jerarquía
 * 
 * @param array $categories Lista de todas las categorías
 * @param int $category_id ID de la categoría
 * @param int $level Nivel actual (para recursión)
 * @return int Nivel de la categoría
 */
function calculateCategoryLevel($categories, $category_id, $level = 0) {
    foreach ($categories as $category) {
        if ($category['id'] == $category_id) {
            if ($category['parent_id'] === null) {
                return $level;
            }
            return calculateCategoryLevel($categories, $category['parent_id'], $level + 1);
        }
    }
    return $level;
}

/**
 * Función para calcular estadísticas de las categorías
 * 
 * @param array $categories Lista de categorías (plana o jerárquica)
 * @param bool $flat Si es lista plana o jerárquica
 * @return array Estadísticas calculadas
 */
function calculateCategoryStats($categories, $flat = false) {
    $stats = [
        'total_categories' => 0,
        'active_categories' => 0,
        'root_categories' => 0,
        'categories_with_items' => 0,
        'total_items' => 0,
        'max_depth' => 0
    ];
    
    if ($flat) {
        // Calcular estadísticas para lista plana
        $stats['total_categories'] = count($categories);
        foreach ($categories as $category) {
            if ($category['is_active']) {
                $stats['active_categories']++;
            }
            if ($category['parent_id'] === null) {
                $stats['root_categories']++;
            }
            if ($category['items_count'] > 0) {
                $stats['categories_with_items']++;
            }
            $stats['total_items'] += $category['items_count'];
        }
    } else {
        // Calcular estadísticas para estructura jerárquica
        $stats = calculateHierarchicalStats($categories, $stats, 0);
    }
    
    return $stats;
}

/**
 * Función recursiva para calcular estadísticas jerárquicas
 * 
 * @param array $categories Categorías en estructura jerárquica
 * @param array $stats Estadísticas actuales
 * @param int $depth Profundidad actual
 * @return array Estadísticas actualizadas
 */
function calculateHierarchicalStats($categories, $stats, $depth = 0) {
    $stats['max_depth'] = max($stats['max_depth'], $depth);
    
    foreach ($categories as $category) {
        $stats['total_categories']++;
        
        if ($category['is_active']) {
            $stats['active_categories']++;
        }
        
        if ($depth === 0) {
            $stats['root_categories']++;
        }
        
        if ($category['items_count'] > 0) {
            $stats['categories_with_items']++;
        }
        
        $stats['total_items'] += $category['items_count'];
        
        // Procesar hijos recursivamente
        if (isset($category['children']) && !empty($category['children'])) {
            $stats = calculateHierarchicalStats($category['children'], $stats, $depth + 1);
        }
    }
    
    return $stats;
}

/**
 * Ejemplos de uso:
 * 
 * // Obtener todas las categorías activas en estructura jerárquica
 * GET /api/inventory/categories/get_categories.php
 * 
 * // Obtener todas las categorías (incluyendo inactivas) en lista plana
 * GET /api/inventory/categories/get_categories.php?include_inactive=true&flat=true
 * 
 * // Obtener solo las subcategorías de una categoría específica
 * GET /api/inventory/categories/get_categories.php?parent_id=1
 * 
 * // Obtener categorías raíz solamente
 * GET /api/inventory/categories/get_categories.php?parent_id=0
 * 
 * Ejemplo de respuesta JSON (estructura jerárquica):
 * 
 * {
 *   "success": true,
 *   "message": "Categorías obtenidas exitosamente",
 *   "data": {
 *     "categories": [
 *       {
 *         "id": 1,
 *         "name": "Repuestos Mecánicos",
 *         "description": "Repuestos para mantenimiento mecánico",
 *         "parent_id": null,
 *         "is_active": true,
 *         "created_at": "2025-01-15 10:30:00",
 *         "updated_at": "2025-01-15 10:30:00",
 *         "children_count": 2,
 *         "items_count": 5,
 *         "has_children": true,
 *         "level": 0,
 *         "children": [
 *           {
 *             "id": 5,
 *             "name": "Filtros",
 *             "description": "Filtros de motor y transmisión",
 *             "parent_id": 1,
 *             "is_active": true,
 *             "created_at": "2025-01-15 10:35:00",
 *             "updated_at": "2025-01-15 10:35:00",
 *             "children_count": 0,
 *             "items_count": 3,
 *             "has_children": false,
 *             "level": 1
 *           }
 *         ]
 *       }
 *     ],
 *     "statistics": {
 *       "total_categories": 4,
 *       "active_categories": 4,
 *       "root_categories": 2,
 *       "categories_with_items": 2,
 *       "total_items": 8,
 *       "max_depth": 2
 *     },
 *     "filters_applied": {
 *       "include_inactive": false,
 *       "parent_id": null,
 *       "flat": false
 *     }
 *   }
 * }
 */
?>