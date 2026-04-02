<?php
/**
 * PUT /api/inventory/categories/update_category.php
 * 
 * Endpoint para actualizar una categoría de inventario existente
 * Maneja cambios en la jerarquía y valida integridad de datos
 * 
 * Campos requeridos:
 * - id: int (ID de la categoría a actualizar)
 * 
 * Campos opcionales (solo se actualizan los campos enviados):
 * - name: string (nombre de la categoría)
 * - description: string (descripción)
 * - parent_id: int (cambiar categoría padre, null para mover a raíz)
 * - is_active: boolean (activar/desactivar categoría)
 * 
 * Nota: Los cambios de parent_id se validan para evitar referencias circulares
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/categories/update_category.php', 'update_category');

header('Content-Type: application/json');

// Solo permitir método PUT
if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido',
        'errors' => ['method' => 'Solo se permite método PUT']
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
    
    // === VALIDAR CAMPO REQUERIDO ===
    if (!isset($input['id']) || !is_numeric($input['id'])) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'ID de la categoría es requerido',
            'errors' => ['id' => 'Se requiere un ID válido de la categoría a actualizar']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    $category_id = intval($input['id']);
    
    // === VERIFICAR QUE LA CATEGORÍA EXISTE ===
    $check_category_sql = "SELECT id, name, description, parent_id, is_active FROM inventory_categories WHERE id = ?";
    $check_stmt = $conn->prepare($check_category_sql);
    $check_stmt->bind_param("i", $category_id);
    $check_stmt->execute();
    $check_result = $check_stmt->get_result();
    $existing_category = $check_result->fetch_assoc();
    
    if (!$existing_category) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Categoría no encontrada',
            'errors' => ['category' => 'La categoría especificada no existe en el sistema']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // === CAMPOS QUE SE PUEDEN ACTUALIZAR ===
    $updatable_fields = ['name', 'description', 'parent_id', 'is_active'];
    $errors = [];
    $update_fields = [];
    $update_types = "";
    $update_values = [];
    
    foreach ($updatable_fields as $field) {
        if (array_key_exists($field, $input)) {
            $value = $input[$field];
            
            // === VALIDACIONES ESPECÍFICAS POR CAMPO ===
            switch ($field) {
                case 'name':
                    if (empty(trim($value))) {
                        $errors['name'] = 'El nombre de la categoría no puede estar vacío';
                        continue 2;
                    }
                    
                    $name = trim($value);
                    
                    // Validar longitud
                    if (strlen($name) < 2) {
                        $errors['name'] = 'El nombre debe tener al menos 2 caracteres';
                        continue 2;
                    } elseif (strlen($name) > 100) {
                        $errors['name'] = 'El nombre no puede exceder 100 caracteres';
                        continue 2;
                    }
                    
                    // Verificar unicidad del nombre en el mismo nivel jerárquico
                    $current_parent_id = array_key_exists('parent_id', $input) ? $input['parent_id'] : $existing_category['parent_id'];
                    
                    if ($current_parent_id) {
                        $check_name_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE name = ? AND parent_id = ? AND id != ?";
                        $check_name_stmt = $conn->prepare($check_name_sql);
                        $check_name_stmt->bind_param("sii", $name, $current_parent_id, $category_id);
                    } else {
                        $check_name_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE name = ? AND parent_id IS NULL AND id != ?";
                        $check_name_stmt = $conn->prepare($check_name_sql);
                        $check_name_stmt->bind_param("si", $name, $category_id);
                    }
                    
                    $check_name_stmt->execute();
                    $check_name_result = $check_name_stmt->get_result();
                    
                    if ($check_name_result->fetch_assoc()['count'] > 0) {
                        $level_text = $current_parent_id ? "en la misma categoría padre" : "en el nivel raíz";
                        $errors['name'] = "Ya existe una categoría con el nombre '{$name}' {$level_text}";
                        continue 2;
                    }
                    
                    $value = $name;
                    $update_types .= "s";
                    break;
                    
                case 'description':
                    $value = !empty(trim($value)) ? trim($value) : null;
                    if ($value && strlen($value) > 500) {
                        $errors['description'] = 'La descripción no puede exceder 500 caracteres';
                        continue 2;
                    }
                    $update_types .= "s";
                    break;
                    
                case 'parent_id':
                    if (!empty($value)) {
                        if (!is_numeric($value)) {
                            $errors['parent_id'] = 'El ID de la categoría padre debe ser un número';
                            continue 2;
                        }
                        
                        $new_parent_id = intval($value);
                        
                        // No puede ser padre de sí misma
                        if ($new_parent_id === $category_id) {
                            $errors['parent_id'] = 'Una categoría no puede ser padre de sí misma';
                            continue 2;
                        }
                        
                        // Verificar que la nueva categoría padre existe y está activa
                        $check_parent_sql = "SELECT id, name FROM inventory_categories WHERE id = ? AND is_active = 1";
                        $check_parent_stmt = $conn->prepare($check_parent_sql);
                        $check_parent_stmt->bind_param("i", $new_parent_id);
                        $check_parent_stmt->execute();
                        $check_parent_result = $check_parent_stmt->get_result();
                        $parent_category = $check_parent_result->fetch_assoc();
                        
                        if (!$parent_category) {
                            $errors['parent_id'] = 'La categoría padre especificada no existe o está inactiva';
                            continue 2;
                        }
                        
                        // Verificar que no se cree una referencia circular
                        if (wouldCreateCircularReference($conn, $category_id, $new_parent_id)) {
                            $errors['parent_id'] = 'El cambio de categoría padre crearía una referencia circular';
                            continue 2;
                        }
                        
                        // Verificar límite de profundidad
                        $new_depth = calculateCategoryDepth($conn, $new_parent_id) + 1;
                        if ($new_depth > 5) {
                            $errors['parent_id'] = 'El cambio excedería el límite máximo de 5 niveles de jerarquía';
                            continue 2;
                        }
                        
                        $value = $new_parent_id;
                        $update_types .= "i";
                    } else {
                        $value = null; // Mover a nivel raíz
                        $update_types .= "i";
                    }
                    break;
                    
                case 'is_active':
                    $new_active_status = filter_var($value, FILTER_VALIDATE_BOOLEAN);
                    
                    // Si se está desactivando, verificar que no tenga hijos activos
                    if (!$new_active_status && boolval($existing_category['is_active'])) {
                        $check_children_sql = "SELECT COUNT(*) as count FROM inventory_categories WHERE parent_id = ? AND is_active = 1";
                        $check_children_stmt = $conn->prepare($check_children_sql);
                        $check_children_stmt->bind_param("i", $category_id);
                        $check_children_stmt->execute();
                        $check_children_result = $check_children_stmt->get_result();
                        
                        if ($check_children_result->fetch_assoc()['count'] > 0) {
                            $errors['is_active'] = 'No se puede desactivar una categoría que tiene subcategorías activas';
                            continue 2;
                        }
                        
                        // Verificar que no tenga items activos
                        $check_items_sql = "SELECT COUNT(*) as count FROM inventory_items WHERE category_id = ? AND is_active = 1";
                        $check_items_stmt = $conn->prepare($check_items_sql);
                        $check_items_stmt->bind_param("i", $category_id);
                        $check_items_stmt->execute();
                        $check_items_result = $check_items_stmt->get_result();
                        
                        if ($check_items_result->fetch_assoc()['count'] > 0) {
                            $errors['is_active'] = 'No se puede desactivar una categoría que tiene items activos asignados';
                            continue 2;
                        }
                    }
                    
                    $value = $new_active_status ? 1 : 0;
                    $update_types .= "i";
                    break;
            }
            
            // Agregar campo a la actualización
            $update_fields[] = "{$field} = ?";
            $update_values[] = $value;
        }
    }
    
    // === VALIDAR ERRORES ===
    if (!empty($errors)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Errores de validación',
            'errors' => $errors
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // === VERIFICAR QUE HAY CAMPOS PARA ACTUALIZAR ===
    if (empty($update_fields)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'No se proporcionaron campos para actualizar',
            'errors' => ['fields' => 'Debe proporcionar al menos un campo válido para actualizar']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }
    
    // === EJECUTAR ACTUALIZACIÓN ===
    $update_sql = "UPDATE inventory_categories 
                   SET " . implode(', ', $update_fields) . ", updated_at = CURRENT_TIMESTAMP 
                   WHERE id = ?";
    
    $update_stmt = $conn->prepare($update_sql);
    
    // Agregar el ID al final de los parámetros
    $update_types .= "i";
    $update_values[] = $category_id;
    
    $update_stmt->bind_param($update_types, ...$update_values);
    $update_result = $update_stmt->execute();
    
    if (!$update_result) {
        throw new Exception('Error al actualizar la categoría en la base de datos');
    }
    
    // === OBTENER CATEGORÍA ACTUALIZADA CON INFORMACIÓN COMPLETA ===
    $get_updated_sql = "SELECT 
        c.*,
        p.name as parent_name,
        (SELECT COUNT(*) FROM inventory_categories cc WHERE cc.parent_id = c.id) as children_count,
        (SELECT COUNT(*) FROM inventory_items ii WHERE ii.category_id = c.id AND ii.is_active = 1) as active_items_count,
        (SELECT COUNT(*) FROM inventory_items ii WHERE ii.category_id = c.id) as total_items_count
    FROM inventory_categories c
    LEFT JOIN inventory_categories p ON c.parent_id = p.id
    WHERE c.id = ?";
    
    $get_updated_stmt = $conn->prepare($get_updated_sql);
    $get_updated_stmt->bind_param("i", $category_id);
    $get_updated_stmt->execute();
    $get_updated_result = $get_updated_stmt->get_result();
    $updated_category = $get_updated_result->fetch_assoc();
    
    // === FORMATEAR DATOS DE RESPUESTA ===
    $updated_category['id'] = intval($updated_category['id']);
    $updated_category['parent_id'] = $updated_category['parent_id'] ? intval($updated_category['parent_id']) : null;
    $updated_category['is_active'] = boolval($updated_category['is_active']);
    $updated_category['children_count'] = intval($updated_category['children_count']);
    $updated_category['active_items_count'] = intval($updated_category['active_items_count']);
    $updated_category['total_items_count'] = intval($updated_category['total_items_count']);
    
    // === GENERAR INFORMACIÓN DE JERARQUÍA ACTUALIZADA ===
    $hierarchy_info = generateHierarchyInfo($conn, $category_id);
    
    // === DETERMINAR CAMPOS CAMBIADOS ===
    $changed_fields = [];
    foreach ($updatable_fields as $field) {
        if (array_key_exists($field, $input)) {
            $changed_fields[] = $field;
        }
    }
    
    // === IMPACTO DE LOS CAMBIOS ===
    $change_impact = [
        'hierarchy_changed' => in_array('parent_id', $changed_fields),
        'name_changed' => in_array('name', $changed_fields),
        'status_changed' => in_array('is_active', $changed_fields),
        'affects_children' => $updated_category['children_count'] > 0,
        'affects_items' => $updated_category['total_items_count'] > 0
    ];
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Categoría actualizada exitosamente',
        'data' => [
            'category' => $updated_category,
            'hierarchy' => $hierarchy_info,
            'changes' => [
                'changed_fields' => $changed_fields,
                'changes_count' => count($changed_fields),
                'impact' => $change_impact
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
 * Función para verificar si un cambio de padre crearía una referencia circular
 */
function wouldCreateCircularReference($conn, $category_id, $new_parent_id) {
    $current_id = $new_parent_id;
    $level = 0;
    
    while ($current_id && $level < 10) { // Protección contra loops infinitos
        if ($current_id === $category_id) {
            return true; // Se encontró referencia circular
        }
        
        // Obtener el padre del padre actual
        $sql = "SELECT parent_id FROM inventory_categories WHERE id = ?";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $current_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        
        if (!$row) {
            break;
        }
        
        $current_id = $row['parent_id'];
        $level++;
    }
    
    return false;
}

/**
 * Función para calcular la profundidad de una categoría
 */
function calculateCategoryDepth($conn, $category_id, $current_depth = 0) {
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
function generateHierarchyInfo($conn, $category_id) {
    $path = [];
    $current_id = $category_id;
    $level = 0;
    
    while ($current_id && $level < 10) {
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
 * // Cambiar solo el nombre
 * {
 *   "id": 5,
 *   "name": "Filtros y Lubricantes"
 * }
 * 
 * // Cambiar descripción
 * {
 *   "id": 5,
 *   "description": "Filtros de aceite, aire, combustible y lubricantes"
 * }
 * 
 * // Mover a otra categoría padre
 * {
 *   "id": 8,
 *   "parent_id": 2
 * }
 * 
 * // Mover a nivel raíz
 * {
 *   "id": 8,
 *   "parent_id": null
 * }
 * 
 * // Desactivar categoría
 * {
 *   "id": 5,
 *   "is_active": false
 * }
 * 
 * // Actualización múltiple
 * {
 *   "id": 5,
 *   "name": "Sistemas de Filtración",
 *   "description": "Filtros y sistemas de filtración industrial",
 *   "parent_id": 1
 * }
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Categoría actualizada exitosamente",
 *   "data": {
 *     "category": {
 *       "id": 5,
 *       "name": "Sistemas de Filtración",
 *       "description": "Filtros y sistemas de filtración industrial",
 *       "parent_id": 1,
 *       "parent_name": "Repuestos Mecánicos",
 *       "is_active": true,
 *       "created_at": "2025-01-15 10:35:00",
 *       "updated_at": "2025-01-15 19:45:00",
 *       "children_count": 2,
 *       "active_items_count": 3,
 *       "total_items_count": 3
 *     },
 *     "hierarchy": {
 *       "path": [
 *         {
 *           "id": 1,
 *           "name": "Repuestos Mecánicos",
 *           "level": 1
 *         },
 *         {
 *           "id": 5,
 *           "name": "Sistemas de Filtración",
 *           "level": 0
 *         }
 *       ],
 *       "depth": 2,
 *       "is_root": false,
 *       "breadcrumb": "Repuestos Mecánicos > Sistemas de Filtración"
 *     },
 *     "changes": {
 *       "changed_fields": ["name", "description", "parent_id"],
 *       "changes_count": 3,
 *       "impact": {
 *         "hierarchy_changed": true,
 *         "name_changed": true,
 *         "status_changed": false,
 *         "affects_children": true,
 *         "affects_items": true
 *       }
 *     }
 *   }
 * }
 */
?>