<?php

/**
 * POST /API_Infoapp/staff/create_staff.php
 * 
 * Endpoint para crear un nuevo empleado
 * Compatible con la estructura de get_staff.php
 */

// ✅ HEADERS CORS MEJORADOS
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, User-ID');
header('Access-Control-Max-Age: 86400');

// ✅ MANEJAR PREFLIGHT REQUEST (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// ✅ LOGGING PARA DEBUG
error_log("create_staff.php - Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("create_staff.php - Content Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        'success' => false,
        'message' => 'Método no permitido. Solo se permite POST.',
        'errors' => ['method' => 'Use POST method']
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Incluir archivo de conexión existente
require_once '../conexion.php';

try {
    // Verificar que la conexión esté disponible
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    error_log("create_staff.php - Database connection OK");

    // ✅ OBTENER DATOS DEL BODY (JSON)
    $input = file_get_contents('php://input');
    error_log("create_staff.php - Raw input: " . $input);

    if (empty($input)) {
        throw new Exception('No se recibieron datos en el cuerpo de la solicitud');
    }

    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    error_log("create_staff.php - Decoded data: " . print_r($data, true));

    // ✅ VALIDAR CAMPOS REQUERIDOS
    $required_fields = [
        'first_name',
        'last_name',
        'email',
        'department_id',
        'position_id',
        'identification_number',
        'hire_date'
    ];

    $errors = [];
    foreach ($required_fields as $field) {
        if (!isset($data[$field]) || trim($data[$field]) === '') {
            $errors[$field] = "Campo $field es requerido";
        }
    }

    // Validar email
    if (isset($data['email']) && !filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
        $errors['email'] = 'Formato de email inválido';
    }

    // Validar department_id y position_id como enteros
    if (isset($data['department_id']) && !is_numeric($data['department_id'])) {
        $errors['department_id'] = 'ID de departamento debe ser numérico';
    }

    if (isset($data['position_id']) && !is_numeric($data['position_id'])) {
        $errors['position_id'] = 'ID de posición debe ser numérico';
    }

    if (!empty($errors)) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => 'Errores de validación',
            'errors' => $errors
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // ✅ VERIFICAR UNICIDAD DE EMAIL
    $email_check_sql = "SELECT id FROM staff WHERE email = ? AND deleted_at IS NULL";
    $email_stmt = $conn->prepare($email_check_sql);
    $email_stmt->bind_param('s', $data['email']);
    $email_stmt->execute();
    $email_result = $email_stmt->get_result();

    if ($email_result->num_rows > 0) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'El email ya está registrado',
            'errors' => ['email' => 'Ya existe un empleado con este email']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // ✅ VERIFICAR UNICIDAD DE IDENTIFICACIÓN
    $id_check_sql = "SELECT id FROM staff WHERE identification_number = ? AND deleted_at IS NULL";
    $id_stmt = $conn->prepare($id_check_sql);
    $id_stmt->bind_param('s', $data['identification_number']);
    $id_stmt->execute();
    $id_result = $id_stmt->get_result();

    if ($id_result->num_rows > 0) {
        http_response_code(409);
        echo json_encode([
            'success' => false,
            'message' => 'El número de identificación ya está registrado',
            'errors' => ['identification_number' => 'Ya existe un empleado con este número de identificación']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // ✅ GENERAR STAFF_CODE AUTOMÁTICO
    $staff_code = 'EMP-' . date('Y') . '-' . strtoupper(substr($data['first_name'], 0, 1)) .
        strtoupper(substr($data['last_name'], 0, 1)) . '-' .
        str_pad(mt_rand(1, 999), 3, '0', STR_PAD_LEFT);

    // Verificar que el código no exista
    $code_check_sql = "SELECT id FROM staff WHERE staff_code = ?";
    $code_stmt = $conn->prepare($code_check_sql);
    $code_stmt->bind_param('s', $staff_code);
    $code_stmt->execute();

    // Si existe, generar otro código
    while ($code_stmt->get_result()->num_rows > 0) {
        $staff_code = 'EMP-' . date('Y') . '-' . strtoupper(substr($data['first_name'], 0, 1)) .
            strtoupper(substr($data['last_name'], 0, 1)) . '-' .
            str_pad(mt_rand(1, 999), 3, '0', STR_PAD_LEFT);
        $code_stmt->bind_param('s', $staff_code);
        $code_stmt->execute();
    }

    error_log("create_staff.php - Generated staff_code: $staff_code");

    // ✅ PREPARAR DATOS PARA INSERCIÓN
    $insert_sql = "INSERT INTO staff (
        staff_code, first_name, last_name, email, phone, department_id, position_id, id_especialidad,
        hire_date, birth_date, identification_type, identification_number, 
        salary, address, emergency_contact_name, emergency_contact_phone, 
        photo_url, is_active, created_at, updated_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), NOW())";

    $stmt = $conn->prepare($insert_sql);
    if (!$stmt) {
        throw new Exception("Error preparando consulta: " . $conn->error);
    }

    // Preparar valores
    $phone = $data['phone'] ?? null;
    $department_id = intval($data['department_id']);
    $position_id = intval($data['position_id']);
    $id_especialidad = (isset($data['id_especialidad']) && !empty($data['id_especialidad'])) ? intval($data['id_especialidad']) : null;
    $hire_date = $data['hire_date'];
    $birth_date = isset($data['birth_date']) && !empty($data['birth_date']) ? $data['birth_date'] : null;
    $identification_type = $data['identification_type'] ?? 'dni';
    $salary = isset($data['salary']) && is_numeric($data['salary']) ? floatval($data['salary']) : null;
    $address = $data['address'] ?? null;
    $emergency_name = $data['emergency_contact_name'] ?? null;
    $emergency_phone = $data['emergency_contact_phone'] ?? null;
    $photo_url = $data['photo_url'] ?? null;
    $is_active = isset($data['is_active']) ? boolval($data['is_active']) : true;

    // Bind parameters
    $stmt->bind_param(
        'sssssiissssdsssssi',
        $staff_code,                    // staff_code
        $data['first_name'],           // first_name
        $data['last_name'],            // last_name  
        $data['email'],                // email
        $phone,                        // phone
        $department_id,                // department_id
        $position_id,                  // position_id
        $id_especialidad,              // id_especialidad (Agregado)
        $hire_date,                    // hire_date
        $birth_date,                   // birth_date
        $identification_type,          // identification_type
        $data['identification_number'], // identification_number
        $salary,                       // salary
        $address,                      // address
        $emergency_name,               // emergency_contact_name
        $emergency_phone,              // emergency_contact_phone
        $photo_url,                    // photo_url
        $is_active                     // is_active
    );

    // ✅ EJECUTAR INSERCIÓN
    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando inserción: " . $stmt->error);
    }

    $new_staff_id = $conn->insert_id;
    error_log("create_staff.php - New staff created with ID: $new_staff_id");

    // ✅ OBTENER EL EMPLEADO RECIÉN CREADO CON JOINS
    $select_sql = "SELECT 
        s.id,
        s.staff_code,
        s.first_name,
        s.last_name,
        s.email,
        s.phone,
        s.department_id,
        COALESCE(d.name, 'Departamento no encontrado') as department_name,
        s.position_id,
        COALESCE(p.title, 'Cargo no encontrado') as position_title,
        s.id_especialidad,
        COALESCE(e.nom_especi, 'Sin especialidad') as especialidad_nombre,
        s.hire_date,
        s.identification_type,
        s.identification_number,
        s.salary,
        s.birth_date,
        s.address,
        s.emergency_contact_name,
        s.emergency_contact_phone,
        s.photo_url,
        s.is_active,
        s.created_at,
        s.updated_at,
        CONCAT(s.first_name, ' ', s.last_name) as full_name,
        CASE WHEN s.photo_url IS NOT NULL AND s.photo_url != '' THEN 1 ELSE 0 END as has_photo,
        CASE WHEN s.emergency_contact_name IS NOT NULL AND s.emergency_contact_name != '' THEN 1 ELSE 0 END as has_emergency_contact,
        CASE 
            WHEN s.hire_date IS NOT NULL THEN TIMESTAMPDIFF(YEAR, s.hire_date, CURDATE())
            ELSE 0 
        END as years_employed
    FROM staff s
    LEFT JOIN departments d ON s.department_id = d.id
    LEFT JOIN positions p ON s.position_id = p.id
    WHERE s.id = ?";

    $select_stmt = $conn->prepare($select_sql);
    $select_stmt->bind_param('i', $new_staff_id);
    $select_stmt->execute();
    $result = $select_stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("No se pudo recuperar el empleado recién creado");
    }

    $staff_data = $result->fetch_assoc();

    // ✅ FORMATEAR DATOS PARA RESPUESTA
    $staff_data['id'] = intval($staff_data['id']);
    $staff_data['department_id'] = intval($staff_data['department_id']);
    $staff_data['position_id'] = intval($staff_data['position_id']);
    $staff_data['id_especialidad'] = $staff_data['id_especialidad'] ? intval($staff_data['id_especialidad']) : null;
    $staff_data['salary'] = $staff_data['salary'] ? floatval($staff_data['salary']) : null;
    $staff_data['is_active'] = boolval($staff_data['is_active']);
    $staff_data['has_photo'] = boolval($staff_data['has_photo']);
    $staff_data['has_emergency_contact'] = boolval($staff_data['has_emergency_contact']);
    $staff_data['years_employed'] = intval($staff_data['years_employed']);

    // ✅ RESPUESTA EXITOSA
    http_response_code(201);

    $response = [
        'success' => true,
        'message' => 'Empleado creado exitosamente',
        'data' => [
            'staff' => $staff_data
        ]
    ];

    error_log("create_staff.php - Success response prepared");
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    // ✅ ERROR LOGGING Y RESPUESTA
    error_log("create_staff.php - Exception: " . $e->getMessage());
    error_log("create_staff.php - Stack trace: " . $e->getTraceAsString());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()],
        'debug_info' => [
            'file' => $e->getFile(),
            'line' => $e->getLine()
        ]
    ], JSON_UNESCAPED_UNICODE);
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}

error_log("create_staff.php - Script execution completed");
