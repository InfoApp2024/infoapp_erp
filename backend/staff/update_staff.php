<?php

/**
 * PUT /API_Infoapp/staff/update_staff.php
 * 
 * Endpoint para actualizar un empleado existente
 * Incluye validaciones completas y verificación de duplicados
 */

// ✅ HEADERS CORS MEJORADOS
header('Content-Type: application/json; charset=UTF-8');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, Accept, User-ID');
header('Access-Control-Max-Age: 86400');

// ✅ LOGGING PARA DEBUG
error_log("update_staff.php - Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("update_staff.php - Content Type: " . ($_SERVER['CONTENT_TYPE'] ?? 'not set'));

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null)
{
    error_log("update_staff.php - Error Response: Status=$statusCode, Message=$message");
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// ✅ MANEJAR PREFLIGHT REQUEST (OPTIONS)
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir método PUT
if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método PUT']);
}

try {
    // Incluir archivo de conexión existente
    require_once '../conexion.php';

    // ✅ VERIFICAR CONEXIÓN MEJORADA
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    error_log("update_staff.php - Database connection OK");

    // ✅ OBTENER DATOS DEL BODY (JSON)
    $input = file_get_contents('php://input');
    error_log("update_staff.php - Raw input: " . $input);

    if (empty($input)) {
        throw new Exception('No se recibieron datos en el cuerpo de la solicitud');
    }

    $data = json_decode($input, true);
    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    error_log("update_staff.php - Decoded data: " . print_r($data, true));

    // Usar $data en lugar de $input para consistencia
    $input = $data;

    // === VALIDAR ID REQUERIDO ===
    if (!isset($input['id']) || empty($input['id']) || !is_numeric($input['id'])) {
        sendErrorResponse(400, 'ID de empleado es requerido y debe ser numérico');
    }

    $staff_id = intval($input['id']);
    error_log("update_staff.php - Updating staff ID: $staff_id");

    // === VERIFICAR QUE EL EMPLEADO EXISTE ===
    $check_staff_sql = "SELECT * FROM staff WHERE id = ?";
    $check_staff_stmt = $conn->prepare($check_staff_sql);
    if (!$check_staff_stmt) {
        throw new Exception('Error preparando consulta de verificación: ' . $conn->error);
    }

    $check_staff_stmt->bind_param("i", $staff_id);
    $check_staff_stmt->execute();
    $staff_result = $check_staff_stmt->get_result();
    $existing_staff = $staff_result->fetch_assoc();
    $check_staff_stmt->close();

    if (!$existing_staff) {
        sendErrorResponse(404, 'Empleado no encontrado', ['id' => 'El empleado especificado no existe']);
    }

    error_log("update_staff.php - Existing staff found: " . $existing_staff['first_name'] . ' ' . $existing_staff['last_name']);

    // === VALIDACIONES DE CAMPOS ===
    $errors = [];

    // === VALIDAR EMAIL ÚNICO (EXCLUIR EMPLEADO ACTUAL) ===
    if (isset($input['email']) && !empty($input['email'])) {
        if (!filter_var($input['email'], FILTER_VALIDATE_EMAIL)) {
            $errors['email'] = "El formato del email no es válido";
        } else {
            $check_email_sql = "SELECT COUNT(*) as count FROM staff WHERE email = ? AND id != ? AND deleted_at IS NULL";
            $check_stmt = $conn->prepare($check_email_sql);

            if (!$check_stmt) {
                throw new Exception('Error preparando consulta de email: ' . $conn->error);
            }

            $email_value = trim($input['email']);
            $check_stmt->bind_param("si", $email_value, $staff_id);
            $check_stmt->execute();
            $email_result = $check_stmt->get_result();
            $email_count = $email_result->fetch_assoc()['count'];
            $check_stmt->close();

            error_log("update_staff.php - Email check for '$email_value': $email_count duplicates found");

            if ($email_count > 0) {
                $errors['email'] = "El email '{$input['email']}' ya está registrado en otro empleado";
            }
        }
    }

    // === VALIDAR NÚMERO DE IDENTIFICACIÓN ÚNICO ===
    if (isset($input['identification_number']) && !empty($input['identification_number'])) {
        $check_id_sql = "SELECT COUNT(*) as count FROM staff WHERE identification_number = ? AND id != ? AND deleted_at IS NULL";
        $check_id_stmt = $conn->prepare($check_id_sql);

        if (!$check_id_stmt) {
            throw new Exception('Error preparando consulta de identificación: ' . $conn->error);
        }

        $id_number = trim($input['identification_number']);
        $check_id_stmt->bind_param("si", $id_number, $staff_id);
        $check_id_stmt->execute();
        $id_result = $check_id_stmt->get_result();
        $id_count = $id_result->fetch_assoc()['count'];
        $check_id_stmt->close();

        error_log("update_staff.php - ID check for '$id_number': $id_count duplicates found");

        if ($id_count > 0) {
            $errors['identification_number'] = "El número de identificación '{$input['identification_number']}' ya está registrado en otro empleado";
        }
    }

    // === VALIDAR TIPO DE IDENTIFICACIÓN ===
    if (isset($input['identification_type']) && !empty($input['identification_type'])) {
        $valid_id_types = ['dni', 'cedula', 'passport'];
        if (!in_array($input['identification_type'], $valid_id_types)) {
            $errors['identification_type'] = "El tipo de identificación debe ser uno de: " . implode(', ', $valid_id_types);
        }
    }

    // === VALIDAR DEPARTAMENTO ===
    if (isset($input['department_id']) && !empty($input['department_id'])) {
        if (!is_numeric($input['department_id'])) {
            $errors['department_id'] = "El departamento debe ser un número válido";
        } else {
            $check_dept_sql = "SELECT COUNT(*) as count FROM departments WHERE id = ? AND is_active = 1";
            $check_dept_stmt = $conn->prepare($check_dept_sql);

            if ($check_dept_stmt) {
                $dept_id = intval($input['department_id']);
                $check_dept_stmt->bind_param("i", $dept_id);
                $check_dept_stmt->execute();
                $dept_result = $check_dept_stmt->get_result();
                $dept_count = $dept_result->fetch_assoc()['count'];
                $check_dept_stmt->close();

                if ($dept_count == 0) {
                    $errors['department_id'] = "El departamento especificado no existe o está inactivo";
                }
            }
        }
    }

    // === VALIDAR POSICIÓN ===
    if (isset($input['position_id']) && !empty($input['position_id'])) {
        if (!is_numeric($input['position_id'])) {
            $errors['position_id'] = "La posición debe ser un número válido";
        } else {
            $check_pos_sql = "SELECT COUNT(*) as count FROM positions WHERE id = ? AND is_active = 1";
            $check_pos_stmt = $conn->prepare($check_pos_sql);

            if ($check_pos_stmt) {
                $pos_id = intval($input['position_id']);
                $check_pos_stmt->bind_param("i", $pos_id);
                $check_pos_stmt->execute();
                $pos_result = $check_pos_stmt->get_result();
                $pos_count = $pos_result->fetch_assoc()['count'];
                $check_pos_stmt->close();

                if ($pos_count == 0) {
                    $errors['position_id'] = "La posición especificada no existe o está inactiva";
                }
            }
        }
    }

    // === VALIDAR ESPECIALIDAD ===
    if (isset($input['id_especialidad']) && !empty($input['id_especialidad'])) {
        if (!is_numeric($input['id_especialidad'])) {
            $errors['id_especialidad'] = "La especialidad debe ser un número válido";
        }
    }

    // === VALIDAR FECHA DE CONTRATACIÓN ===
    if (isset($input['hire_date']) && !empty($input['hire_date'])) {
        if (!DateTime::createFromFormat('Y-m-d', $input['hire_date'])) {
            $errors['hire_date'] = "La fecha de contratación debe tener formato YYYY-MM-DD";
        } else {
            $hire_date_obj = DateTime::createFromFormat('Y-m-d', $input['hire_date']);
            $today = new DateTime();
            if ($hire_date_obj > $today) {
                $errors['hire_date'] = "La fecha de contratación no puede ser futura";
            }
        }
    }

    // === VALIDAR FECHA DE NACIMIENTO ===
    if (isset($input['birth_date']) && !empty($input['birth_date'])) {
        if (!DateTime::createFromFormat('Y-m-d', $input['birth_date'])) {
            $errors['birth_date'] = "La fecha de nacimiento debe tener formato YYYY-MM-DD";
        } else {
            $birth_date_obj = DateTime::createFromFormat('Y-m-d', $input['birth_date']);
            $today = new DateTime();
            if ($birth_date_obj > $today) {
                $errors['birth_date'] = "La fecha de nacimiento no puede ser futura";
            }

            // Validar edad mínima (16 años)
            $age = $today->diff($birth_date_obj)->y;
            if ($age < 16) {
                $errors['birth_date'] = "El empleado debe tener al menos 16 años";
            }
        }
    }

    // === VALIDAR TELÉFONO ===
    if (isset($input['phone']) && !empty($input['phone'])) {
        $phone = trim($input['phone']);
        if (strlen($phone) < 10) {
            $errors['phone'] = "El teléfono debe tener al menos 10 dígitos";
        }
    }

    // === VALIDAR SALARIO ===
    if (isset($input['salary']) && !empty($input['salary'])) {
        if (!is_numeric($input['salary']) || floatval($input['salary']) < 0) {
            $errors['salary'] = "El salario debe ser un número positivo";
        }
    }

    // === VALIDAR CAMPOS REQUERIDOS PARA ACTUALIZACIÓN ===
    if (isset($input['first_name']) && empty(trim($input['first_name']))) {
        $errors['first_name'] = "El nombre no puede estar vacío";
    }

    if (isset($input['last_name']) && empty(trim($input['last_name']))) {
        $errors['last_name'] = "El apellido no puede estar vacío";
    }

    // Si hay errores de validación, devolver error 400
    if (!empty($errors)) {
        error_log("update_staff.php - Validation errors: " . print_r($errors, true));
        sendErrorResponse(400, 'Errores de validación', $errors);
    }

    // === OBTENER USUARIO ACTUALIZADOR ===
    $updated_by = null;
    if (isset($input['updated_by']) && !empty($input['updated_by'])) {
        $updated_by = intval($input['updated_by']);
    } elseif (isset($_SERVER['HTTP_USER_ID']) && !empty($_SERVER['HTTP_USER_ID'])) {
        $updated_by = intval($_SERVER['HTTP_USER_ID']);
    }

    error_log("update_staff.php - Updated by: " . ($updated_by ?? 'unknown'));

    // === PREPARAR CAMPOS PARA ACTUALIZACIÓN ===
    $update_fields = [];
    $update_values = [];
    $update_types = "";

    // Solo actualizar campos que se envían en el request
    if (isset($input['first_name'])) {
        $update_fields[] = "first_name = ?";
        $update_values[] = trim($input['first_name']);
        $update_types .= "s";
    }

    if (isset($input['last_name'])) {
        $update_fields[] = "last_name = ?";
        $update_values[] = trim($input['last_name']);
        $update_types .= "s";
    }

    if (isset($input['email'])) {
        $update_fields[] = "email = ?";
        $update_values[] = trim($input['email']);
        $update_types .= "s";
    }

    if (isset($input['phone'])) {
        $update_fields[] = "phone = ?";
        $update_values[] = !empty($input['phone']) ? trim($input['phone']) : null;
        $update_types .= "s";
    }

    if (isset($input['department_id'])) {
        $update_fields[] = "department_id = ?";
        $update_values[] = intval($input['department_id']);
        $update_types .= "i";
    }

    if (isset($input['position_id'])) {
        $update_fields[] = "position_id = ?";
        $update_values[] = intval($input['position_id']);
        $update_types .= "i";
    }

    if (isset($input['id_especialidad'])) {
        $update_fields[] = "id_especialidad = ?";
        $update_values[] = !empty($input['id_especialidad']) ? intval($input['id_especialidad']) : null;
        $update_types .= "i";
    }

    if (isset($input['hire_date'])) {
        $update_fields[] = "hire_date = ?";
        $update_values[] = $input['hire_date'];
        $update_types .= "s";
    }

    if (isset($input['identification_type'])) {
        $update_fields[] = "identification_type = ?";
        $update_values[] = $input['identification_type'];
        $update_types .= "s";
    }

    if (isset($input['identification_number'])) {
        $update_fields[] = "identification_number = ?";
        $update_values[] = trim($input['identification_number']);
        $update_types .= "s";
    }

    if (isset($input['salary'])) {
        $update_fields[] = "salary = ?";
        $update_values[] = !empty($input['salary']) ? floatval($input['salary']) : null;
        $update_types .= "d";
    }

    if (isset($input['birth_date'])) {
        $update_fields[] = "birth_date = ?";
        $update_values[] = !empty($input['birth_date']) ? $input['birth_date'] : null;
        $update_types .= "s";
    }

    if (isset($input['address'])) {
        $update_fields[] = "address = ?";
        $update_values[] = !empty($input['address']) ? trim($input['address']) : null;
        $update_types .= "s";
    }

    if (isset($input['emergency_contact_name'])) {
        $update_fields[] = "emergency_contact_name = ?";
        $update_values[] = !empty($input['emergency_contact_name']) ? trim($input['emergency_contact_name']) : null;
        $update_types .= "s";
    }

    if (isset($input['emergency_contact_phone'])) {
        $update_fields[] = "emergency_contact_phone = ?";
        $update_values[] = !empty($input['emergency_contact_phone']) ? trim($input['emergency_contact_phone']) : null;
        $update_types .= "s";
    }

    if (isset($input['photo_url'])) {
        $update_fields[] = "photo_url = ?";
        $update_values[] = !empty($input['photo_url']) ? trim($input['photo_url']) : null;
        $update_types .= "s";
    }

    if (isset($input['is_active'])) {
        $update_fields[] = "is_active = ?";
        $update_values[] = boolval($input['is_active']) ? 1 : 0;
        $update_types .= "i";
    }

    // Siempre actualizar updated_at y updated_by
    $update_fields[] = "updated_at = NOW()";

    if ($updated_by !== null) {
        $update_fields[] = "updated_by = ?";
        $update_values[] = $updated_by;
        $update_types .= "i";
    }

    // Verificar que hay campos para actualizar
    if (empty($update_fields)) {
        sendErrorResponse(400, 'No se proporcionaron campos para actualizar');
    }

    error_log("update_staff.php - Updating fields: " . implode(", ", $update_fields));
    error_log("update_staff.php - Update values: " . print_r($update_values, true));

    // === INICIAR TRANSACCIÓN ===
    $conn->autocommit(false);

    try {
        // === ACTUALIZAR EMPLEADO ===
        $update_sql = "UPDATE staff SET " . implode(", ", $update_fields) . " WHERE id = ?";

        // Agregar el ID al final de los valores y tipos
        $update_values[] = $staff_id;
        $update_types .= "i";

        error_log("update_staff.php - SQL: $update_sql");

        $update_stmt = $conn->prepare($update_sql);
        if (!$update_stmt) {
            throw new Exception("Error preparando actualización: " . $conn->error);
        }

        // Usar call_user_func_array para bind_param dinámico
        $refs = array();
        foreach ($update_values as $key => $value) {
            $refs[$key] = &$update_values[$key];
        }

        call_user_func_array(
            array($update_stmt, 'bind_param'),
            array_merge(array($update_types), $refs)
        );

        if (!$update_stmt->execute()) {
            throw new Exception("Error al actualizar el empleado: " . $update_stmt->error);
        }

        $affected_rows = $update_stmt->affected_rows;
        $update_stmt->close();

        error_log("update_staff.php - Rows affected: $affected_rows");

        if ($affected_rows === 0) {
            error_log("update_staff.php - Warning: No rows affected (data might be identical)");
        }

        // === CONFIRMAR TRANSACCIÓN ===
        $conn->commit();
        error_log("update_staff.php - Transaction committed successfully");

        // === OBTENER EMPLEADO ACTUALIZADO CON INFORMACIÓN COMPLETA ===
        $get_staff_sql = "SELECT 
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

        $get_staff_stmt = $conn->prepare($get_staff_sql);
        if (!$get_staff_stmt) {
            throw new Exception("Error preparando consulta de obtención: " . $conn->error);
        }

        $get_staff_stmt->bind_param("i", $staff_id);
        if (!$get_staff_stmt->execute()) {
            throw new Exception("Error ejecutando consulta de obtención: " . $get_staff_stmt->error);
        }

        $get_result = $get_staff_stmt->get_result();
        $updated_staff = $get_result->fetch_assoc();
        $get_staff_stmt->close();

        if (!$updated_staff) {
            throw new Exception("No se pudo obtener el empleado actualizado");
        }

        // === FORMATEAR DATOS DEL EMPLEADO ACTUALIZADO ===
        $updated_staff['id'] = intval($updated_staff['id']);
        $updated_staff['department_id'] = intval($updated_staff['department_id']);
        $updated_staff['position_id'] = intval($updated_staff['position_id']);
        $updated_staff['salary'] = $updated_staff['salary'] ? floatval($updated_staff['salary']) : null;
        $updated_staff['is_active'] = boolval($updated_staff['is_active']);
        $updated_staff['has_photo'] = boolval($updated_staff['has_photo']);
        $updated_staff['has_emergency_contact'] = boolval($updated_staff['has_emergency_contact']);
        $updated_staff['years_employed'] = intval($updated_staff['years_employed']);

        // === RESPUESTA EXITOSA ===
        http_response_code(200);

        $response = [
            'success' => true,
            'message' => 'Empleado actualizado exitosamente',
            'data' => [
                'staff' => $updated_staff  // ✅ ENVUELTO EN "staff" como create_staff.php
            ]
        ];

        error_log("update_staff.php - Success response prepared");
        echo json_encode($response, JSON_UNESCAPED_UNICODE);
    } catch (Exception $e) {
        // Revertir transacción
        $conn->rollback();
        error_log("update_staff.php - Transaction rolled back due to error: " . $e->getMessage());
        throw $e;
    } finally {
        // Restaurar autocommit
        $conn->autocommit(true);
    }
} catch (Exception $e) {
    // ✅ ERROR LOGGING Y RESPUESTA
    error_log("update_staff.php - Exception: " . $e->getMessage());
    error_log("update_staff.php - Stack trace: " . $e->getTraceAsString());

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

error_log("update_staff.php - Script execution completed");
