<?php

/**
 * POST /api/inventory/categories/create_category.php
 * 
 * Endpoint para crear una nueva categoría de inventario
 * Soporta estructura jerárquica (categorías padre e hijos)
 * 
 * Campos requeridos:
 * - name: string (nombre de la categoría, único por nivel)
 * 
 * Campos opcionales:
 * - description: string (descripción de la categoría)
 * - parent_id: int (ID de la categoría padre, null para categoría raíz)
 * - is_active: boolean (estado activo, default: true)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/categories/create_category.php', 'create_category');

header('Content-Type: application/json');

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

// Incluir archivo de conexión existente
require_once '../../conexion.php'; // Desde categories/ hacia API_Infoapp/

try {
    // Verificar conexión
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    // Obtener datos del cuerpo de la petición
    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('No se recibieron datos válidos en formato JSON');
    }

    // === VALIDACIONES DE CAMPOS REQUERIDOS ===
    $errors = [];

    // Validar nombre
    if (!isset($input['name']) || empty(trim($input['name']))) {
        $errors['name'] = 'El nombre de la categoría es requerido';
    } else {
        $name = trim($input['name']);

        // Validar longitud del nombre
        if (strlen($name) < 2) {
            $errors['name'] = 'El nombre debe tener al menos 2 caracteres';
        } elseif (strlen($name) > 100) {
            $errors['name'] = 'El nombre no puede exceder 100 caracteres';
        }
    }

    // === VALIDAR CATEGORÍA PADRE ===
    $parent_id = null;
    $parent_category = null;
    if (!empty($input['parent_id'])) {
        if (!is_numeric($input['parent_id'])) {
            $errors['parent_id'] = 'El ID de la categoría padre debe ser un número';
        } else {
            $parent_id = intval($input['parent_id']);

            // Verificar que la categoría padre existe y está activa
            $check_parent_sql = "SELECT id, name FROM inventory_categories WHERE id = ? AND is_active = 1";
            $check_parent_stmt = $conn->prepare($check_parent_sql);
            $check_parent_stmt->bind_param("i", $parent_id);
            $check_parent_stmt->execute();
            $check_parent_result = $check_parent_stmt->get_result();
            $parent_category = $check_parent_result->fetch_assoc();

            if (!$parent_category) {
                $errors['parent_id'] = 'La categoría padre especificada no existe o está inactiva';
            }
        }
    }

    // === VALIDAR UNICIDAD DEL NOMBRE ===
    if (!isset($errors['name'])) {
        if ($parent_id) {
            $check_name_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE name = ? AND parent_id = ?";
            $check_name_stmt = $conn->prepare($check_name_sql);
            $check_name_stmt->bind_param("si", $name, $parent_id);
        } else {
            $check_name_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE name = ? AND parent_id IS NULL";
            $check_name_stmt = $conn->prepare($check_name_sql);
            $check_name_stmt->bind_param("s", $name);
        }

        $check_name_stmt->execute();
        $check_name_result = $check_name_stmt->get_result();

        if ($check_name_result->fetch_assoc()['count'] > 0) {
            $level_text = $parent_id ? "en la categoría padre '{$parent_category['name']}'" : "en el nivel raíz";
            $errors['name'] = "Ya existe una categoría con el nombre '{$name}' {$level_text}";
        }
    }

    // === VALIDAR DESCRIPCIÓN ===
    $description = null;
    if (isset($input['description']) && !empty(trim($input['description']))) {
        $description = trim($input['description']);
        if (strlen($description) > 500) {
            $errors['description'] = 'La descripción no puede exceder 500 caracteres';
        }
    }

    // Validar estado activo
    $is_active = isset($input['is_active']) ? filter_var($input['is_active'], FILTER_VALIDATE_BOOLEAN) : true;

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

    // === VERIFICAR PROFUNDIDAD MÁXIMA ===
    if ($parent_id) {
        $depth = calculateCategoryDepth($conn, $parent_id);
        if ($depth >= 5) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => 'Límite de jerarquía excedido',
                'errors' => ['hierarchy' => 'No se pueden crear más de 5 niveles de categorías']
            ], JSON_UNESCAPED_UNICODE);
            exit();
        }
    }

    // === INSERTAR CATEGORÍA ===
    $insert_sql = "INSERT INTO inventory_categories (name, description, parent_id, is_active) VALUES (?, ?, ?, ?)";
    $insert_stmt = $conn->prepare($insert_sql);
    $is_active_int = $is_active ? 1 : 0;
    $insert_stmt->bind_param("ssii", $name, $description, $parent_id, $is_active_int);
    $insert_result = $insert_stmt->execute();

    if (!$insert_result) {
        throw new Exception('Error al crear la categoría en la base de datos');
    }

    $category_id = $conn->insert_id;

    // === OBTENER CATEGORÍA CREADA ===
    $get_category_sql = "SELECT 
        c.*,
        p.name as parent_name,
        (SELECT COUNT(*) FROM inventory_categories cc WHERE cc.parent_id = c.id) as children_count,
        (SELECT COUNT(*) FROM inventory_items ii WHERE ii.category_id = c.id) as items_count
    FROM inventory_categories c
    LEFT JOIN inventory_categories p ON c.parent_id = p.id
    WHERE c.id = ?";

    $get_category_stmt = $conn->prepare($get_category_sql);
    $get_category_stmt->bind_param("i", $category_id);
    $get_category_stmt->execute();
    $get_category_result = $get_category_stmt->get_result();
    $created_category = $get_category_result->fetch_assoc();

    // Formatear datos de respuesta
    $created_category['id'] = intval($created_category['id']);
    $created_category['parent_id'] = $created_category['parent_id'] ? intval($created_category['parent_id']) : null;
    $created_category['is_active'] = boolval($created_category['is_active']);
    $created_category['children_count'] = intval($created_category['children_count']);
    $created_category['items_count'] = intval($created_category['items_count']);

    // === GENERAR INFORMACIÓN DE JERARQUÍA ===
    $hierarchy_info = generateHierarchyInfo($conn, $category_id);

    // === RESPUESTA EXITOSA ===
    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Categoría creada exitosamente',
        'data' => [
            'category' => $created_category,
            'hierarchy' => $hierarchy_info
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
 * Función para calcular la profundidad de una categoría en la jerarquía
 */
function calculateCategoryDepth($conn, $category_id, $current_depth = 0)
{
    if ($current_depth > 10) { // Protección contra loops infinitos
        return $current_depth;
    }

    $sql = "SELECT parent_id FROM inventory_categories WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $category_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if (!$row || !$row['parent_id']) {
        return $current_depth + 1;
    }

    return calculateCategoryDepth($conn, $row['parent_id'], $current_depth + 1);
}

/**
 * Función para generar información de jerarquía
 */
function generateHierarchyInfo($conn, $category_id)
{
    $path = [];
    $current_id = $category_id;
    $level = 0;

    // Construir path desde la categoría actual hasta la raíz
    while ($current_id && $level < 10) { // Protección contra loops
        $sql = "SELECT id, name, parent_id FROM inventory_categories WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $current_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $category = $result->fetch_assoc();

        if (!$category) break;

        array_unshift($path, [
            'id' => intval($category['id']),
            'name' => $category['name'],
            'level' => $level
        ]);

        $current_id = $category['parent_id'] ? intval($category['parent_id']) : null;
        $level++;
    }

    return [
        'path' => $path,
        'depth' => count($path),
        'is_root' => count($path) === 1,
        'breadcrumb' => implode(' > ', array_column($path, 'name'))
    ];
}

/**
 * Ejemplos de peticiones JSON:
 * 
 * // Categoría raíz
 * {
 *   "name": "Repuestos Mecánicos",
 *   "description": "Repuestos y componentes mecánicos para mantenimiento"
 * }
 * 
 * // Subcategoría
 * {
 *   "name": "Filtros",
 *   "description": "Filtros de aceite, aire y combustible",
 *   "parent_id": 1
 * }
 * 
 * // Sub-subcategoría
 * {
 *   "name": "Filtros de Aceite",
 *   "description": "Filtros específicos para aceite de motor",
 *   "parent_id": 5
 * }
 * 
 * // Categoría inactiva
 * {
 *   "name": "Categoría Temporal",
 *   "description": "Categoría para pruebas",
 *   "is_active": false
 * }
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Categoría creada exitosamente",
 *   "data": {
 *     "category": {
 *       "id": 8,
 *       "name": "Filtros de Aceite",
 *       "description": "Filtros específicos para aceite de motor",
 *       "parent_id": 5,
 *       "parent_name": "Filtros",
 *       "is_active": true,
 *       "created_at": "2025-01-15 18:30:00",
 *       "updated_at": "2025-01-15 18:30:00",
 *       "children_count": 0,
 *       "items_count": 0
 *     },
 *     "hierarchy": {
 *       "path": [
 *         {
 *           "id": 1,
 *           "name": "Repuestos Mecánicos",
 *           "level": 2
 *         },
 *         {
 *           "id": 5,
 *           "name": "Filtros",
 *           "level": 1
 *         },
 *         {
 *           "id": 8,
 *           "name": "Filtros de Aceite",
 *           "level": 0
 *         }
 *       ],
 *       "depth": 3,
 *       "is_root": false,
 *       "breadcrumb": "Repuestos Mecánicos > Filtros > Filtros de Aceite"
 *     }
 *   }
 * }
 */
