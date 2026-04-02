<?php
/**
 * PUT /api/inventory/suppliers/update_supplier.php
 * 
 * Endpoint para actualizar un proveedor de inventario existente
 * Incluye validaciones de formato y verificación de duplicados
 * 
 * Campos requeridos:
 * - id: int (ID del proveedor a actualizar)
 * - name: string (nombre del proveedor, único)
 * 
 * Campos opcionales:
 * - contact_person: string (persona de contacto)
 * - email: string (email de contacto, con validación de formato)
 * - phone: string (teléfono de contacto)
 * - address: string (dirección física)
 * - tax_id: string (identificación fiscal/NIT, único)
 * - is_active: boolean (estado activo)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

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
require_once '../../conexion.php'; // Desde suppliers/ hacia API_Infoapp/

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
    
    // Validar ID (requerido para actualizar)
    if (!isset($input['id']) || !is_numeric($input['id']) || $input['id'] <= 0) {
        $errors['id'] = 'El ID del proveedor es requerido y debe ser un número válido';
    } else {
        $supplier_id = intval($input['id']);
        
        // Verificar que el proveedor existe
        $check_exists_sql = "SELECT COUNT(*) as count FROM suppliers WHERE id = ?";
        $check_exists_stmt = $conn->prepare($check_exists_sql);
        $check_exists_stmt->bind_param("i", $supplier_id);
        $check_exists_stmt->execute();
        $check_exists_result = $check_exists_stmt->get_result();
        
        if ($check_exists_result->fetch_assoc()['count'] == 0) {
            $errors['id'] = "No existe un proveedor con el ID {$supplier_id}";
        }
    }
    
    // Validar nombre (requerido)
    if (!isset($input['name']) || empty(trim($input['name']))) {
        $errors['name'] = 'El nombre del proveedor es requerido';
    } else {
        $name = trim($input['name']);
        
        // Validar longitud del nombre
        if (strlen($name) < 2) {
            $errors['name'] = 'El nombre debe tener al menos 2 caracteres';
        } elseif (strlen($name) > 200) {
            $errors['name'] = 'El nombre no puede exceder 200 caracteres';
        }
        
        // Verificar que el nombre no esté duplicado (excluyendo el registro actual)
        if (!isset($errors['name']) && !isset($errors['id'])) {
            $check_name_sql = "SELECT COUNT(*) as count FROM suppliers WHERE name = ? AND id != ?";
            $check_name_stmt = $conn->prepare($check_name_sql);
            $check_name_stmt->bind_param("si", $name, $supplier_id);
            $check_name_stmt->execute();
            $check_name_result = $check_name_stmt->get_result();
            
            if ($check_name_result->fetch_assoc()['count'] > 0) {
                $errors['name'] = "Ya existe otro proveedor con el nombre '{$name}'";
            }
        }
    }
    
    // === VALIDACIONES DE CAMPOS OPCIONALES ===
    
    // Validar persona de contacto
    $contact_person = null;
    if (isset($input['contact_person']) && !empty(trim($input['contact_person']))) {
        $contact_person = trim($input['contact_person']);
        if (strlen($contact_person) > 100) {
            $errors['contact_person'] = 'La persona de contacto no puede exceder 100 caracteres';
        }
    }
    
    // Validar email
    $email = null;
    if (isset($input['email']) && !empty(trim($input['email']))) {
        $email = trim($input['email']);
        
        if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
            $errors['email'] = 'El formato del email no es válido';
        } elseif (strlen($email) > 100) {
            $errors['email'] = 'El email no puede exceder 100 caracteres';
        } else {
            // Verificar que el email no esté duplicado (excluyendo el registro actual)
            if (!isset($errors['id'])) {
                $check_email_sql = "SELECT COUNT(*) as count FROM suppliers WHERE email = ? AND id != ?";
                $check_email_stmt = $conn->prepare($check_email_sql);
                $check_email_stmt->bind_param("si", $email, $supplier_id);
                $check_email_stmt->execute();
                $check_email_result = $check_email_stmt->get_result();
                
                if ($check_email_result->fetch_assoc()['count'] > 0) {
                    $errors['email'] = "Ya existe otro proveedor con el email '{$email}'";
                }
            }
        }
    }
    
    // Validar teléfono
    $phone = null;
    if (isset($input['phone']) && !empty(trim($input['phone']))) {
        $phone = trim($input['phone']);
        
        // Validar formato básico de teléfono (números, espacios, guiones, paréntesis, +)
        if (!preg_match('/^[\d\s\-\(\)\+]+$/', $phone)) {
            $errors['phone'] = 'El teléfono solo puede contener números, espacios, guiones, paréntesis y el símbolo +';
        } elseif (strlen($phone) < 7) {
            $errors['phone'] = 'El teléfono debe tener al menos 7 caracteres';
        } elseif (strlen($phone) > 20) {
            $errors['phone'] = 'El teléfono no puede exceder 20 caracteres';
        }
    }
    
    // Validar dirección
    $address = null;
    if (isset($input['address']) && !empty(trim($input['address']))) {
        $address = trim($input['address']);
        if (strlen($address) > 500) {
            $errors['address'] = 'La dirección no puede exceder 500 caracteres';
        }
    }
    
    // Validar identificación fiscal/NIT
    $tax_id = null;
    if (isset($input['tax_id']) && !empty(trim($input['tax_id']))) {
        $tax_id = trim($input['tax_id']);
        
        if (strlen($tax_id) < 5) {
            $errors['tax_id'] = 'La identificación fiscal debe tener al menos 5 caracteres';
        } elseif (strlen($tax_id) > 50) {
            $errors['tax_id'] = 'La identificación fiscal no puede exceder 50 caracteres';
        } else {
            // Verificar que el tax_id no esté duplicado (excluyendo el registro actual)
            if (!isset($errors['id'])) {
                $check_tax_sql = "SELECT COUNT(*) as count FROM suppliers WHERE tax_id = ? AND id != ?";
                $check_tax_stmt = $conn->prepare($check_tax_sql);
                $check_tax_stmt->bind_param("si", $tax_id, $supplier_id);
                $check_tax_stmt->execute();
                $check_tax_result = $check_tax_stmt->get_result();
                
                if ($check_tax_result->fetch_assoc()['count'] > 0) {
                    $errors['tax_id'] = "Ya existe otro proveedor con la identificación fiscal '{$tax_id}'";
                }
            }
        }
    }
    
    // Validar estado activo
    $is_active = isset($input['is_active']) ? filter_var($input['is_active'], FILTER_VALIDATE_BOOLEAN) : null;
    
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
    
    // === ACTUALIZAR PROVEEDOR ===
    
    // Construir query dinámicamente según campos enviados
    $update_fields = [];
    $update_params = [];
    $param_types = "";
    
    // Campo obligatorio: name
    $update_fields[] = "name = ?";
    $update_params[] = $name;
    $param_types .= "s";
    
    // Campos opcionales
    if ($contact_person !== null) {
        $update_fields[] = "contact_person = ?";
        $update_params[] = $contact_person;
        $param_types .= "s";
    } elseif (isset($input['contact_person'])) {
        // Si se envía explícitamente como null o vacío, limpiar el campo
        $update_fields[] = "contact_person = NULL";
    }
    
    if ($email !== null) {
        $update_fields[] = "email = ?";
        $update_params[] = $email;
        $param_types .= "s";
    } elseif (isset($input['email'])) {
        $update_fields[] = "email = NULL";
    }
    
    if ($phone !== null) {
        $update_fields[] = "phone = ?";
        $update_params[] = $phone;
        $param_types .= "s";
    } elseif (isset($input['phone'])) {
        $update_fields[] = "phone = NULL";
    }
    
    if ($address !== null) {
        $update_fields[] = "address = ?";
        $update_params[] = $address;
        $param_types .= "s";
    } elseif (isset($input['address'])) {
        $update_fields[] = "address = NULL";
    }
    
    if ($tax_id !== null) {
        $update_fields[] = "tax_id = ?";
        $update_params[] = $tax_id;
        $param_types .= "s";
    } elseif (isset($input['tax_id'])) {
        $update_fields[] = "tax_id = NULL";
    }
    
    if ($is_active !== null) {
        $update_fields[] = "is_active = ?";
        $update_params[] = $is_active ? 1 : 0;
        $param_types .= "i";
    }
    
    // Siempre actualizar updated_at
    $update_fields[] = "updated_at = NOW()";
    
    // Agregar ID al final para la cláusula WHERE
    $update_params[] = $supplier_id;
    $param_types .= "i";
    
    $update_sql = "UPDATE suppliers SET " . implode(", ", $update_fields) . " WHERE id = ?";
    
    $update_stmt = $conn->prepare($update_sql);
    $update_stmt->bind_param($param_types, ...$update_params);
    $update_result = $update_stmt->execute();
    
    if (!$update_result) {
        throw new Exception('Error al actualizar el proveedor en la base de datos');
    }
    
    // Verificar si se actualizó algún registro
    if ($update_stmt->affected_rows === 0) {
        // Puede ser que no hubo cambios o que el ID no existe
        $check_exists_sql = "SELECT COUNT(*) as count FROM suppliers WHERE id = ?";
        $check_exists_stmt = $conn->prepare($check_exists_sql);
        $check_exists_stmt->bind_param("i", $supplier_id);
        $check_exists_stmt->execute();
        $check_exists_result = $check_exists_stmt->get_result();
        
        if ($check_exists_result->fetch_assoc()['count'] == 0) {
            throw new Exception("No se encontró el proveedor con ID {$supplier_id}");
        }
        // Si existe pero no se actualizó, probablemente no hubo cambios
    }
    
    // === OBTENER PROVEEDOR ACTUALIZADO CON INFORMACIÓN ADICIONAL ===
    $get_supplier_sql = "SELECT 
        s.*,
        COUNT(ii.id) as items_count,
        COALESCE(SUM(ii.current_stock * ii.unit_cost), 0) as total_inventory_value
    FROM suppliers s
    LEFT JOIN inventory_items ii ON s.id = ii.supplier_id AND ii.is_active = 1
    WHERE s.id = ?
    GROUP BY s.id, s.name, s.contact_person, s.email, s.phone, s.address, s.tax_id, s.is_active, s.created_at, s.updated_at";
    
    $get_supplier_stmt = $conn->prepare($get_supplier_sql);
    $get_supplier_stmt->bind_param("i", $supplier_id);
    $get_supplier_stmt->execute();
    $get_supplier_result = $get_supplier_stmt->get_result();
    $updated_supplier = $get_supplier_result->fetch_assoc();
    
    if (!$updated_supplier) {
        throw new Exception("Error al obtener el proveedor actualizado");
    }
    
    // Formatear datos de respuesta
    $updated_supplier['is_active'] = boolval($updated_supplier['is_active']);
    $updated_supplier['items_count'] = intval($updated_supplier['items_count']);
    $updated_supplier['total_inventory_value'] = floatval($updated_supplier['total_inventory_value']);
    
    // === GENERAR INFORMACIÓN ADICIONAL ===
    $supplier_info = [
        'contact_methods' => [],
        'has_complete_info' => true,
        'missing_fields' => [],
        'verification_status' => 'pending'
    ];
    
    // Determinar métodos de contacto disponibles
    if ($updated_supplier['email']) {
        $supplier_info['contact_methods'][] = 'email';
    }
    if ($updated_supplier['phone']) {
        $supplier_info['contact_methods'][] = 'phone';
    }
    if ($updated_supplier['address']) {
        $supplier_info['contact_methods'][] = 'address';
    }
    
    // Determinar campos faltantes para información completa
    $optional_fields = [
        'contact_person' => 'Persona de contacto',
        'email' => 'Email',
        'phone' => 'Teléfono',
        'address' => 'Dirección',
        'tax_id' => 'Identificación fiscal'
    ];
    
    foreach ($optional_fields as $field => $description) {
        if (empty($updated_supplier[$field])) {
            $supplier_info['missing_fields'][] = $description;
        }
    }
    
    $supplier_info['has_complete_info'] = empty($supplier_info['missing_fields']);
    $supplier_info['completeness_percentage'] = round(
        ((5 - count($supplier_info['missing_fields'])) / 5) * 100, 1
    );
    
    // Estado de verificación basado en la información disponible
    if ($updated_supplier['email'] && $updated_supplier['phone'] && $updated_supplier['tax_id']) {
        $supplier_info['verification_status'] = 'ready_for_verification';
    } elseif ($updated_supplier['email'] || $updated_supplier['phone']) {
        $supplier_info['verification_status'] = 'partial_info';
    } else {
        $supplier_info['verification_status'] = 'incomplete';
    }
    
    // === RESPUESTA EXITOSA ===
    http_response_code(200);
    echo json_encode([
        'success' => true,
        'message' => 'Proveedor actualizado exitosamente',
        'data' => [
            'supplier' => $updated_supplier,
            'supplier_info' => $supplier_info
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
 * Ejemplos de peticiones JSON:
 * 
 * // Actualizar solo el nombre
 * {
 *   "id": 1,
 *   "name": "Nuevo Nombre del Proveedor"
 * }
 * 
 * // Actualizar información completa
 * {
 *   "id": 2,
 *   "name": "Filtros y Componentes Ltda - Actualizado",
 *   "contact_person": "María García Rodríguez",
 *   "email": "maria.garcia@filtrosycomponentes.com",
 *   "phone": "+57 (1) 555-9999",
 *   "address": "Calle 50 #15-40, Bogotá, Colombia",
 *   "tax_id": "900123456-2"
 * }
 * 
 * // Desactivar proveedor
 * {
 *   "id": 3,
 *   "name": "Proveedor Temporal",
 *   "is_active": false
 * }
 * 
 * // Limpiar campos opcionales (enviar como string vacío o null)
 * {
 *   "id": 4,
 *   "name": "Proveedor Básico",
 *   "contact_person": "",
 *   "email": null,
 *   "phone": "",
 *   "address": null,
 *   "tax_id": ""
 * }
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Proveedor actualizado exitosamente",
 *   "data": {
 *     "supplier": {
 *       "id": 2,
 *       "name": "Filtros y Componentes Ltda - Actualizado",
 *       "contact_person": "María García Rodríguez",
 *       "email": "maria.garcia@filtrosycomponentes.com",
 *       "phone": "+57 (1) 555-9999",
 *       "address": "Calle 50 #15-40, Bogotá, Colombia",
 *       "tax_id": "900123456-2",
 *       "is_active": true,
 *       "created_at": "2025-01-15 19:00:00",
 *       "updated_at": "2025-01-15 20:30:00",
 *       "items_count": 3,
 *       "total_inventory_value": 1250.75
 *     },
 *     "supplier_info": {
 *       "contact_methods": ["email", "phone", "address"],
 *       "has_complete_info": true,
 *       "missing_fields": [],
 *       "completeness_percentage": 100,
 *       "verification_status": "ready_for_verification"
 *     }
 *   }
 * }
 */
?>