<?php
/**
 * POST /api/inventory/suppliers/create_supplier.php
 * 
 * Endpoint para crear un nuevo proveedor de inventario
 * Incluye validaciones de formato y verificación de duplicados
 * 
 * Campos requeridos:
 * - name: string (nombre del proveedor, único)
 * 
 * Campos opcionales:
 * - contact_person: string (persona de contacto)
 * - email: string (email de contacto, con validación de formato)
 * - phone: string (teléfono de contacto)
 * - address: string (dirección física)
 * - tax_id: string (identificación fiscal/NIT, único)
 * - is_active: boolean (estado activo, default: true)
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();

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
        
        // Verificar que el nombre no esté duplicado
        if (!isset($errors['name'])) {
            $check_name_sql = "SELECT COUNT(*) as count FROM suppliers WHERE name = ?";
            $check_name_stmt = $conn->prepare($check_name_sql);
            $check_name_stmt->bind_param("s", $name);
            $check_name_stmt->execute();
            $check_name_result = $check_name_stmt->get_result();
            
            if ($check_name_result->fetch_assoc()['count'] > 0) {
                $errors['name'] = "Ya existe un proveedor con el nombre '{$name}'";
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
            // Verificar que el email no esté duplicado
            $check_email_sql = "SELECT COUNT(*) as count FROM suppliers WHERE email = ?";
            $check_email_stmt = $conn->prepare($check_email_sql);
            $check_email_stmt->bind_param("s", $email);
            $check_email_stmt->execute();
            $check_email_result = $check_email_stmt->get_result();
            
            if ($check_email_result->fetch_assoc()['count'] > 0) {
                $errors['email'] = "Ya existe un proveedor con el email '{$email}'";
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
            // Verificar que el tax_id no esté duplicado
            $check_tax_sql = "SELECT COUNT(*) as count FROM suppliers WHERE tax_id = ?";
            $check_tax_stmt = $conn->prepare($check_tax_sql);
            $check_tax_stmt->bind_param("s", $tax_id);
            $check_tax_stmt->execute();
            $check_tax_result = $check_tax_stmt->get_result();
            
            if ($check_tax_result->fetch_assoc()['count'] > 0) {
                $errors['tax_id'] = "Ya existe un proveedor con la identificación fiscal '{$tax_id}'";
            }
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
    
    // === INSERTAR PROVEEDOR ===
    $insert_sql = "INSERT INTO suppliers (name, contact_person, email, phone, address, tax_id, is_active) 
                   VALUES (?, ?, ?, ?, ?, ?, ?)";
    
    $insert_stmt = $conn->prepare($insert_sql);
    $is_active_int = $is_active ? 1 : 0;
    $insert_stmt->bind_param("ssssssi", $name, $contact_person, $email, $phone, $address, $tax_id, $is_active_int);
    $insert_result = $insert_stmt->execute();
    
    if (!$insert_result) {
        throw new Exception('Error al crear el proveedor en la base de datos');
    }
    
    $supplier_id = $conn->insert_id;
    
    // === OBTENER PROVEEDOR CREADO CON INFORMACIÓN ADICIONAL ===
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
    $created_supplier = $get_supplier_result->fetch_assoc();
    
    // Formatear datos de respuesta
    $created_supplier['is_active'] = boolval($created_supplier['is_active']);
    $created_supplier['items_count'] = intval($created_supplier['items_count']);
    $created_supplier['total_inventory_value'] = floatval($created_supplier['total_inventory_value']);
    
    // === GENERAR INFORMACIÓN ADICIONAL ===
    $supplier_info = [
        'contact_methods' => [],
        'has_complete_info' => true,
        'missing_fields' => [],
        'verification_status' => 'pending'
    ];
    
    // Determinar métodos de contacto disponibles
    if ($created_supplier['email']) {
        $supplier_info['contact_methods'][] = 'email';
    }
    if ($created_supplier['phone']) {
        $supplier_info['contact_methods'][] = 'phone';
    }
    if ($created_supplier['address']) {
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
        if (empty($created_supplier[$field])) {
            $supplier_info['missing_fields'][] = $description;
        }
    }
    
    $supplier_info['has_complete_info'] = empty($supplier_info['missing_fields']);
    $supplier_info['completeness_percentage'] = round(
        ((5 - count($supplier_info['missing_fields'])) / 5) * 100, 1
    );
    
    // Estado de verificación basado en la información disponible
    if ($created_supplier['email'] && $created_supplier['phone'] && $created_supplier['tax_id']) {
        $supplier_info['verification_status'] = 'ready_for_verification';
    } elseif ($created_supplier['email'] || $created_supplier['phone']) {
        $supplier_info['verification_status'] = 'partial_info';
    } else {
        $supplier_info['verification_status'] = 'incomplete';
    }
    
    // === RESPUESTA EXITOSA ===
    http_response_code(201);
    echo json_encode([
        'success' => true,
        'message' => 'Proveedor creado exitosamente',
        'data' => [
            'supplier' => $created_supplier,
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
 * // Proveedor básico (solo nombre)
 * {
 *   "name": "Repuestos Industriales SA"
 * }
 * 
 * // Proveedor completo
 * {
 *   "name": "Filtros y Componentes Ltda",
 *   "contact_person": "María García",
 *   "email": "maria@filtrosycomponentes.com",
 *   "phone": "+57 (1) 555-1234",
 *   "address": "Calle 45 #12-34, Bogotá, Colombia",
 *   "tax_id": "900123456-1"
 * }
 * 
 * // Proveedor internacional
 * {
 *   "name": "Mann Filter International",
 *   "contact_person": "John Smith",
 *   "email": "john.smith@mannfilter.com",
 *   "phone": "+1-555-987-6543",
 *   "address": "123 Industrial Ave, Detroit, MI 48201, USA",
 *   "tax_id": "US-123456789"
 * }
 * 
 * // Proveedor inactivo
 * {
 *   "name": "Proveedor Temporal",
 *   "email": "temp@example.com",
 *   "is_active": false
 * }
 * 
 * Ejemplo de respuesta JSON:
 * 
 * {
 *   "success": true,
 *   "message": "Proveedor creado exitosamente",
 *   "data": {
 *     "supplier": {
 *       "id": 4,
 *       "name": "Filtros y Componentes Ltda",
 *       "contact_person": "María García",
 *       "email": "maria@filtrosycomponentes.com",
 *       "phone": "+57 (1) 555-1234",
 *       "address": "Calle 45 #12-34, Bogotá, Colombia",
 *       "tax_id": "900123456-1",
 *       "is_active": true,
 *       "created_at": "2025-01-15 19:00:00",
 *       "updated_at": "2025-01-15 19:00:00",
 *       "items_count": 0,
 *       "total_inventory_value": 0
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