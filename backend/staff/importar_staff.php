<?php
/**
 * POST /API_Infoapp/staff/importar_staff.php
 * 
 * Endpoint para importar empleados desde archivo Excel o CSV
 * Incluye validaciones, creación de departamentos/posiciones automática
 */

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, User-ID');

// Función para enviar respuesta de error
function sendErrorResponse($statusCode, $message, $errors = null) {
    http_response_code($statusCode);
    echo json_encode([
        'success' => false,
        'message' => $message,
        'errors' => $errors
    ], JSON_UNESCAPED_UNICODE);
    exit();
}

// Función para generar código de empleado único
function generateStaffCode($conn) {
    $attempts = 0;
    $maxAttempts = 10;
    
    while ($attempts < $maxAttempts) {
        $code = 'STF' . str_pad(rand(100000, 999999), 6, '0', STR_PAD_LEFT);
        
        $check_sql = "SELECT COUNT(*) as count FROM staff WHERE staff_code = ?";
        $check_stmt = $conn->prepare($check_sql);
        $check_stmt->bind_param("s", $code);
        $check_stmt->execute();
        $result = $check_stmt->get_result();
        $count = $result->fetch_assoc()['count'];
        $check_stmt->close();
        
        if ($count == 0) {
            return $code;
        }
        
        $attempts++;
    }
    
    throw new Exception("No se pudo generar un código único de empleado");
}

// Función para crear departamento si no existe
function createDepartmentIfNotExists($conn, $departmentName, $createdBy = null) {
    if (empty($departmentName)) {
        return null;
    }
    
    // Buscar departamento existente
    $search_sql = "SELECT id FROM departments WHERE name = ? AND is_active = 1";
    $search_stmt = $conn->prepare($search_sql);
    $search_stmt->bind_param("s", $departmentName);
    $search_stmt->execute();
    $search_result = $search_stmt->get_result();
    $existing_dept = $search_result->fetch_assoc();
    $search_stmt->close();
    
    if ($existing_dept) {
        return $existing_dept['id'];
    }
    
    // Crear nuevo departamento
    $create_sql = "INSERT INTO departments (name, description, is_active, created_by, created_at) VALUES (?, ?, 1, ?, NOW())";
    $create_stmt = $conn->prepare($create_sql);
    $description = "Departamento creado automáticamente durante importación";
    $create_stmt->bind_param("ssi", $departmentName, $description, $createdBy);
    
    if ($create_stmt->execute()) {
        $new_id = $conn->insert_id;
        $create_stmt->close();
        return $new_id;
    }
    
    $create_stmt->close();
    return null;
}

// Función para crear posición si no existe
function createPositionIfNotExists($conn, $positionTitle, $departmentId, $createdBy = null) {
    if (empty($positionTitle) || empty($departmentId)) {
        return null;
    }
    
    // Buscar posición existente
    $search_sql = "SELECT id FROM positions WHERE title = ? AND department_id = ? AND is_active = 1";
    $search_stmt = $conn->prepare($search_sql);
    $search_stmt->bind_param("si", $positionTitle, $departmentId);
    $search_stmt->execute();
    $search_result = $search_stmt->get_result();
    $existing_pos = $search_result->fetch_assoc();
    $search_stmt->close();
    
    if ($existing_pos) {
        return $existing_pos['id'];
    }
    
    // Crear nueva posición
    $create_sql = "INSERT INTO positions (title, description, department_id, is_active, created_by, created_at) VALUES (?, ?, ?, 1, ?, NOW())";
    $create_stmt = $conn->prepare($create_sql);
    $description = "Posición creada automáticamente durante importación";
    $create_stmt->bind_param("ssii", $positionTitle, $description, $departmentId, $createdBy);
    
    if ($create_stmt->execute()) {
        $new_id = $conn->insert_id;
        $create_stmt->close();
        return $new_id;
    }
    
    $create_stmt->close();
    return null;
}

// Función para validar datos del empleado
function validateStaffData($data, $row_number) {
    $errors = [];
    
    // Campos requeridos
    if (empty($data['first_name'])) {
        $errors[] = "Fila {$row_number}: Nombre es requerido";
    }
    
    if (empty($data['last_name'])) {
        $errors[] = "Fila {$row_number}: Apellido es requerido";
    }
    
    if (empty($data['email'])) {
        $errors[] = "Fila {$row_number}: Email es requerido";
    } elseif (!filter_var($data['email'], FILTER_VALIDATE_EMAIL)) {
        $errors[] = "Fila {$row_number}: Formato de email inválido";
    }
    
    if (empty($data['identification_number'])) {
        $errors[] = "Fila {$row_number}: Número de identificación es requerido";
    }
    
    if (empty($data['department_name'])) {
        $errors[] = "Fila {$row_number}: Departamento es requerido";
    }
    
    if (empty($data['position_title'])) {
        $errors[] = "Fila {$row_number}: Posición es requerida";
    }
    
    // Validar tipo de identificación
    $valid_id_types = ['dni', 'cedula', 'passport'];
    if (!empty($data['identification_type']) && !in_array($data['identification_type'], $valid_id_types)) {
        $errors[] = "Fila {$row_number}: Tipo de identificación debe ser: " . implode(', ', $valid_id_types);
    }
    
    // Validar fecha de contratación
    if (!empty($data['hire_date'])) {
        $hire_date = DateTime::createFromFormat('Y-m-d', $data['hire_date']);
        if (!$hire_date) {
            $errors[] = "Fila {$row_number}: Fecha de contratación debe tener formato YYYY-MM-DD";
        } elseif ($hire_date > new DateTime()) {
            $errors[] = "Fila {$row_number}: Fecha de contratación no puede ser futura";
        }
    }
    
    // Validar fecha de nacimiento
    if (!empty($data['birth_date'])) {
        $birth_date = DateTime::createFromFormat('Y-m-d', $data['birth_date']);
        if (!$birth_date) {
            $errors[] = "Fila {$row_number}: Fecha de nacimiento debe tener formato YYYY-MM-DD";
        } elseif ($birth_date > new DateTime()) {
            $errors[] = "Fila {$row_number}: Fecha de nacimiento no puede ser futura";
        } else {
            $age = (new DateTime())->diff($birth_date)->y;
            if ($age < 16) {
                $errors[] = "Fila {$row_number}: El empleado debe tener al menos 16 años";
            }
        }
    }
    
    // Validar salario
    if (!empty($data['salary'])) {
        if (!is_numeric($data['salary']) || floatval($data['salary']) < 0) {
            $errors[] = "Fila {$row_number}: Salario debe ser un número positivo";
        }
    }
    
    return $errors;
}

// Manejar preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Solo permitir método POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendErrorResponse(405, 'Método no permitido', ['method' => 'Solo se permite método POST']);
}

try {
    // Incluir dependencias para leer archivos
    require_once '../../vendor/autoload.php';
    require_once '../../conexion.php';

    // Verificar conexión
    if (!$conn || $conn->connect_error) {
        sendErrorResponse(500, 'Error de conexión a la base de datos');
    }
    
    // Obtener datos del request
    $inputRaw = file_get_contents('php://input');
    $input = json_decode($inputRaw, true);
    
    if (!$input) {
        sendErrorResponse(400, 'No se recibieron datos válidos en formato JSON');
    }
    
    // Verificar que se proporcione el archivo
    if (!isset($input['archivo_base64']) || empty($input['archivo_base64'])) {
        sendErrorResponse(400, 'Se requiere el archivo en formato base64');
    }
    
    if (!isset($input['nombre_archivo']) || empty($input['nombre_archivo'])) {
        sendErrorResponse(400, 'Se requiere el nombre del archivo');
    }
    
    // Obtener opciones de importación
    $options = $input['options'] ?? [];
    $update_existing = $options['update_existing'] ?? false;
    $create_departments = $options['create_departments'] ?? true;
    $create_positions = $options['create_positions'] ?? true;
    $skip_first_row = $options['skip_first_row'] ?? true;
    $date_format = $options['date_format'] ?? 'Y-m-d';
    
    // Obtener usuario actual
    $created_by = null;
    if (isset($input['created_by']) && !empty($input['created_by'])) {
        $created_by = intval($input['created_by']);
    } elseif (isset($_SERVER['HTTP_USER_ID']) && !empty($_SERVER['HTTP_USER_ID'])) {
        $created_by = intval($_SERVER['HTTP_USER_ID']);
    }
    
    // Decodificar archivo
    $file_content = base64_decode($input['archivo_base64']);
    if ($file_content === false) {
        sendErrorResponse(400, 'Error al decodificar el archivo base64');
    }
    
    // Crear archivo temporal
    $temp_file = tempnam(sys_get_temp_dir(), 'staff_import_');
    file_put_contents($temp_file, $file_content);
    
    $data_rows = [];
    $file_extension = strtolower(pathinfo($input['nombre_archivo'], PATHINFO_EXTENSION));
    
    try {
        if (in_array($file_extension, ['xlsx', 'xls'])) {
            // Procesar archivo Excel
            $reader = \PhpOffice\PhpSpreadsheet\IOFactory::createReader('Xlsx');
            $reader->setReadDataOnly(true);
            $spreadsheet = $reader->load($temp_file);
            $worksheet = $spreadsheet->getActiveSheet();
            $data_rows = $worksheet->toArray();
            
        } elseif ($file_extension === 'csv') {
            // Procesar archivo CSV
            $handle = fopen($temp_file, 'r');
            if ($handle) {
                while (($row = fgetcsv($handle)) !== false) {
                    $data_rows[] = $row;
                }
                fclose($handle);
            }
        } else {
            throw new Exception("Formato de archivo no soportado. Use Excel (.xlsx) o CSV (.csv)");
        }
        
    } catch (Exception $e) {
        unlink($temp_file);
        sendErrorResponse(400, 'Error al procesar el archivo: ' . $e->getMessage());
    }
    
    // Limpiar archivo temporal
    unlink($temp_file);
    
    if (empty($data_rows)) {
        sendErrorResponse(400, 'El archivo está vacío o no se pudo leer');
    }
    
    // Obtener headers (primera fila)
    $headers = array_shift($data_rows);
    if ($skip_first_row && !empty($data_rows)) {
        // Los headers ya fueron removidos arriba
    }
    
    // Mapear headers a índices
    $header_map = [];
    foreach ($headers as $index => $header) {
        $clean_header = strtolower(trim($header));
        $header_map[$clean_header] = $index;
    }
    
    // Mapeo de campos esperados
    $field_mapping = [
        'first_name' => ['nombres', 'first_name', 'nombre'],
        'last_name' => ['apellidos', 'last_name', 'apellido'],
        'email' => ['email', 'correo', 'e-mail'],
        'phone' => ['telefono', 'phone', 'teléfono', 'celular'],
        'department_name' => ['departamento', 'department', 'department_name'],
        'position_title' => ['cargo', 'position', 'position_title', 'puesto'],
        'hire_date' => ['fecha_ingreso', 'hire_date', 'fecha_contratacion', 'ingreso'],
        'identification_type' => ['tipo_documento', 'identification_type', 'tipo_id'],
        'identification_number' => ['numero_documento', 'identification_number', 'documento', 'cedula'],
        'salary' => ['salario', 'salary', 'sueldo'],
        'birth_date' => ['fecha_nacimiento', 'birth_date', 'nacimiento'],
        'address' => ['direccion', 'address', 'dirección'],
        'emergency_contact_name' => ['contacto_emergencia', 'emergency_contact', 'contacto_emergencia_nombre'],
        'emergency_contact_phone' => ['telefono_emergencia', 'emergency_phone', 'contacto_emergencia_telefono']
    ];
    
    // Encontrar índices de campos
    $field_indices = [];
    foreach ($field_mapping as $field => $possible_names) {
        foreach ($possible_names as $name) {
            if (isset($header_map[$name])) {
                $field_indices[$field] = $header_map[$name];
                break;
            }
        }
    }
    
    // Verificar campos requeridos
    $required_fields = ['first_name', 'last_name', 'email', 'identification_number'];
    $missing_fields = [];
    foreach ($required_fields as $field) {
        if (!isset($field_indices[$field])) {
            $missing_fields[] = $field;
        }
    }
    
    if (!empty($missing_fields)) {
        sendErrorResponse(400, 'Faltan columnas requeridas en el archivo: ' . implode(', ', $missing_fields));
    }
    
    // Contadores
    $total_rows = count($data_rows);
    $processed = 0;
    $inserted = 0;
    $updated = 0;
    $errors = 0;
    $error_details = [];
    
    // Iniciar transacción
    $conn->autocommit(false);
    
    try {
        // Procesar cada fila
        foreach ($data_rows as $row_index => $row) {
            $row_number = $row_index + 2; // +2 porque empezamos en fila 2 (después de headers)
            
            try {
                // Extraer datos de la fila
                $staff_data = [];
                foreach ($field_indices as $field => $index) {
                    $staff_data[$field] = isset($row[$index]) ? trim($row[$index]) : '';
                }
                
                // Saltar filas vacías
                if (empty($staff_data['first_name']) && empty($staff_data['last_name']) && empty($staff_data['email'])) {
                    continue;
                }
                
                $processed++;
                
                // Validar datos
                $validation_errors = validateStaffData($staff_data, $row_number);
                if (!empty($validation_errors)) {
                    $error_details = array_merge($error_details, $validation_errors);
                    $errors++;
                    continue;
                }
                
                // Verificar si el empleado ya existe
                $existing_staff = null;
                $check_sql = "SELECT id FROM staff WHERE email = ? OR identification_number = ?";
                $check_stmt = $conn->prepare($check_sql);
                $check_stmt->bind_param("ss", $staff_data['email'], $staff_data['identification_number']);
                $check_stmt->execute();
                $check_result = $check_stmt->get_result();
                $existing_staff = $check_result->fetch_assoc();
                $check_stmt->close();
                
                if ($existing_staff && !$update_existing) {
                    $error_details[] = "Fila {$row_number}: Empleado ya existe (email o identificación duplicada)";
                    $errors++;
                    continue;
                }
                
                // Crear/obtener departamento
                $department_id = null;
                if (!empty($staff_data['department_name'])) {
                    if ($create_departments) {
                        $department_id = createDepartmentIfNotExists($conn, $staff_data['department_name'], $created_by);
                    } else {
                        // Buscar departamento existente
                        $dept_sql = "SELECT id FROM departments WHERE name = ? AND is_active = 1";
                        $dept_stmt = $conn->prepare($dept_sql);
                        $dept_stmt->bind_param("s", $staff_data['department_name']);
                        $dept_stmt->execute();
                        $dept_result = $dept_stmt->get_result();
                        $dept_data = $dept_result->fetch_assoc();
                        $dept_stmt->close();
                        $department_id = $dept_data ? $dept_data['id'] : null;
                    }
                }
                
                if (!$department_id) {
                    $error_details[] = "Fila {$row_number}: No se pudo crear/encontrar el departamento: {$staff_data['department_name']}";
                    $errors++;
                    continue;
                }
                
                // Crear/obtener posición
                $position_id = null;
                if (!empty($staff_data['position_title'])) {
                    if ($create_positions) {
                        $position_id = createPositionIfNotExists($conn, $staff_data['position_title'], $department_id, $created_by);
                    } else {
                        // Buscar posición existente
                        $pos_sql = "SELECT id FROM positions WHERE title = ? AND department_id = ? AND is_active = 1";
                        $pos_stmt = $conn->prepare($pos_sql);
                        $pos_stmt->bind_param("si", $staff_data['position_title'], $department_id);
                        $pos_stmt->execute();
                        $pos_result = $pos_stmt->get_result();
                        $pos_data = $pos_result->fetch_assoc();
                        $pos_stmt->close();
                        $position_id = $pos_data ? $pos_data['id'] : null;
                    }
                }
                
                if (!$position_id) {
                    $error_details[] = "Fila {$row_number}: No se pudo crear/encontrar la posición: {$staff_data['position_title']}";
                    $errors++;
                    continue;
                }
                
                // Preparar datos para insertar/actualizar
                $hire_date = !empty($staff_data['hire_date']) ? $staff_data['hire_date'] : date('Y-m-d');
                $identification_type = !empty($staff_data['identification_type']) ? $staff_data['identification_type'] : 'cedula';
                $salary = !empty($staff_data['salary']) ? floatval($staff_data['salary']) : null;
                $birth_date = !empty($staff_data['birth_date']) ? $staff_data['birth_date'] : null;
                
                if ($existing_staff && $update_existing) {
                    // Actualizar empleado existente
                    $update_sql = "UPDATE staff SET 
                        first_name = ?, last_name = ?, phone = ?, department_id = ?, position_id = ?,
                        hire_date = ?, salary = ?, birth_date = ?, address = ?,
                        emergency_contact_name = ?, emergency_contact_phone = ?, updated_by = ?, updated_at = NOW()
                        WHERE id = ?";
                    
                    $update_stmt = $conn->prepare($update_sql);
                    $update_stmt->bind_param(
                        "ssssisssssiii",
                        $staff_data['first_name'],
                        $staff_data['last_name'],
                        $staff_data['phone'],
                        $department_id,
                        $position_id,
                        $hire_date,
                        $salary,
                        $birth_date,
                        $staff_data['address'],
                        $staff_data['emergency_contact_name'],
                        $staff_data['emergency_contact_phone'],
                        $created_by,
                        $existing_staff['id']
                    );
                    
                    if ($update_stmt->execute()) {
                        $updated++;
                    } else {
                        $error_details[] = "Fila {$row_number}: Error al actualizar empleado: " . $update_stmt->error;
                        $errors++;
                    }
                    $update_stmt->close();
                    
                } else {
                    // Insertar nuevo empleado
                    $staff_code = generateStaffCode($conn);
                    
                    $insert_sql = "INSERT INTO staff (
                        staff_code, first_name, last_name, email, phone, department_id, position_id,
                        hire_date, identification_type, identification_number, salary, birth_date,
                        address, emergency_contact_name, emergency_contact_phone, is_active, created_by
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)";
                    
                    $insert_stmt = $conn->prepare($insert_sql);
                    $insert_stmt->bind_param(
                        "sssssiisssdsssi",
                        $staff_code,
                        $staff_data['first_name'],
                        $staff_data['last_name'],
                        $staff_data['email'],
                        $staff_data['phone'],
                        $department_id,
                        $position_id,
                        $hire_date,
                        $identification_type,
                        $staff_data['identification_number'],
                        $salary,
                        $birth_date,
                        $staff_data['address'],
                        $staff_data['emergency_contact_name'],
                        $staff_data['emergency_contact_phone'],
                        $created_by
                    );
                    
                    if ($insert_stmt->execute()) {
                        $inserted++;
                    } else {
                        $error_details[] = "Fila {$row_number}: Error al insertar empleado: " . $insert_stmt->error;
                        $errors++;
                    }
                    $insert_stmt->close();
                }
                
            } catch (Exception $e) {
                $error_details[] = "Fila {$row_number}: Error procesando datos: " . $e->getMessage();
                $errors++;
            }
        }
        
        // Confirmar transacción
        $conn->commit();
        
        // Respuesta exitosa
        http_response_code(200);
        echo json_encode([
            'success' => true,
            'message' => 'Importación completada',
            'total_filas' => $total_rows,
            'procesadas' => $processed,
            'insertados' => $inserted,
            'actualizados' => $updated,
            'errores' => $errors,
            'errores_detalle' => $error_details
        ], JSON_UNESCAPED_UNICODE);
        
    } catch (Exception $e) {
        // Revertir transacción
        $conn->rollback();
        throw $e;
    } finally {
        // Restaurar autocommit
        $conn->autocommit(true);
    }
    
} catch (Exception $e) {
    sendErrorResponse(500, 'Error interno del servidor: ' . $e->getMessage());
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}
?>