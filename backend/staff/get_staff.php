<?php

/**
 * GET /API_Infoapp/staff/get_staff.php
 * 
 * Endpoint para obtener lista de empleados con filtros y paginación
 * CORREGIDO con manejo completo de CORS
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
error_log("get_staff.php - Request Method: " . $_SERVER['REQUEST_METHOD']);
error_log("get_staff.php - Query String: " . $_SERVER['QUERY_STRING']);

// Incluir archivo de conexión existente
require_once '../conexion.php';

try {
    // Verificar que la conexión esté disponible
    if ($conn->connect_error) {
        throw new Exception("Error de conexión: " . $conn->connect_error);
    }

    error_log("get_staff.php - Database connection OK");

    // === OBTENER PARÁMETROS DE CONSULTA ===
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $department_id = isset($_GET['department_id']) ? intval($_GET['department_id']) : null;
    $position_id = isset($_GET['position_id']) ? intval($_GET['position_id']) : null;
    $is_active = isset($_GET['is_active']) ? $_GET['is_active'] : null;
    $include_inactive = isset($_GET['include_inactive']) ? filter_var($_GET['include_inactive'], FILTER_VALIDATE_BOOLEAN) : false;
    $hire_date_from = isset($_GET['hire_date_from']) ? trim($_GET['hire_date_from']) : '';
    $hire_date_to = isset($_GET['hire_date_to']) ? trim($_GET['hire_date_to']) : '';
    $salary_min = isset($_GET['salary_min']) ? floatval($_GET['salary_min']) : null;
    $salary_max = isset($_GET['salary_max']) ? floatval($_GET['salary_max']) : null;
    $identification_type = isset($_GET['identification_type']) ? trim($_GET['identification_type']) : '';

    // === PARÁMETROS DE PAGINACIÓN ===
    $limit = isset($_GET['limit']) ? max(1, min(100, intval($_GET['limit']))) : 20;
    $offset = isset($_GET['offset']) ? max(0, intval($_GET['offset'])) : 0;

    // === PARÁMETROS DE ORDENAMIENTO ===
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'first_name';
    $sort_order = isset($_GET['sort_order']) && strtoupper($_GET['sort_order']) === 'DESC' ? 'DESC' : 'ASC';

    // Campos válidos para ordenamiento
    $valid_sort_fields = [
        'id',
        'staff_code',
        'first_name',
        'last_name',
        'email',
        'phone',
        'department_id',
        'position_id',
        'hire_date',
        'salary',
        'is_active',
        'created_at',
        'updated_at'
    ];

    if (!in_array($sort_by, $valid_sort_fields)) {
        $sort_by = 'first_name';
    }

    error_log("get_staff.php - Parameters: limit=$limit, offset=$offset, search='$search'");

    // === CONSULTA BASE PARA CONTAR REGISTROS ===
    $count_sql = "SELECT COUNT(*) as total 
                  FROM staff s
                  LEFT JOIN departments d ON s.department_id = d.id
                  LEFT JOIN positions p ON s.position_id = p.id
                  WHERE 1=1";

    // === CONSULTA PRINCIPAL ===
    $sql = "SELECT 
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
                -- Campos calculados
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
            LEFT JOIN especialidades e ON s.id_especialidad = e.id
            WHERE 1=1";

    // === CONSTRUIR CONDICIONES WHERE ===
    $where_conditions = [];
    $count_where_conditions = [];
    $params = [];
    $types = "";

    // Filtro por estado activo/inactivo
    if ($is_active !== null) {
        if ($is_active === 'true' || $is_active === '1') {
            $where_conditions[] = "s.is_active = 1";
            $count_where_conditions[] = "s.is_active = 1";
        } elseif ($is_active === 'false' || $is_active === '0') {
            $where_conditions[] = "s.is_active = 0";
            $count_where_conditions[] = "s.is_active = 0";
        }
    } elseif (!$include_inactive) {
        // Por defecto, solo mostrar activos
        $where_conditions[] = "s.is_active = 1";
        $count_where_conditions[] = "s.is_active = 1";
    }

    // Filtro de búsqueda general
    if (!empty($search)) {
        $search_condition = "(s.staff_code LIKE ? OR s.first_name LIKE ? OR s.last_name LIKE ? OR 
                            s.email LIKE ? OR s.identification_number LIKE ? OR 
                            CONCAT(s.first_name, ' ', s.last_name) LIKE ?)";
        $where_conditions[] = $search_condition;
        $count_where_conditions[] = $search_condition;

        $search_param = '%' . $search . '%';
        for ($i = 0; $i < 6; $i++) {
            $params[] = $search_param;
            $types .= 's';
        }
    }

    // Filtro por departamento
    if ($department_id && $department_id > 0) {
        $where_conditions[] = "s.department_id = ?";
        $count_where_conditions[] = "s.department_id = ?";
        $params[] = $department_id;
        $types .= 'i';
    }

    // Filtro por posición
    if ($position_id && $position_id > 0) {
        $where_conditions[] = "s.position_id = ?";
        $count_where_conditions[] = "s.position_id = ?";
        $params[] = $position_id;
        $types .= 'i';
    }

    // Filtro por tipo de identificación
    if (!empty($identification_type)) {
        $where_conditions[] = "s.identification_type = ?";
        $count_where_conditions[] = "s.identification_type = ?";
        $params[] = $identification_type;
        $types .= 's';
    }

    // Filtro por rango de fechas de contratación
    if (!empty($hire_date_from)) {
        $where_conditions[] = "s.hire_date >= ?";
        $count_where_conditions[] = "s.hire_date >= ?";
        $params[] = $hire_date_from;
        $types .= 's';
    }

    if (!empty($hire_date_to)) {
        $where_conditions[] = "s.hire_date <= ?";
        $count_where_conditions[] = "s.hire_date <= ?";
        $params[] = $hire_date_to;
        $types .= 's';
    }

    // Filtro por rango de salario
    if ($salary_min && $salary_min > 0) {
        $where_conditions[] = "s.salary >= ?";
        $count_where_conditions[] = "s.salary >= ?";
        $params[] = $salary_min;
        $types .= 'd';
    }

    if ($salary_max && $salary_max > 0) {
        $where_conditions[] = "s.salary <= ?";
        $count_where_conditions[] = "s.salary <= ?";
        $params[] = $salary_max;
        $types .= 'd';
    }

    // Construir WHERE clauses
    if (!empty($where_conditions)) {
        $sql .= " AND " . implode(" AND ", $where_conditions);
    }

    if (!empty($count_where_conditions)) {
        $count_sql .= " AND " . implode(" AND ", $count_where_conditions);
    }

    // === EJECUTAR CONSULTA DE CONTEO ===
    $count_stmt = $conn->prepare($count_sql);
    if (!$count_stmt) {
        throw new Exception("Error preparando consulta de conteo: " . $conn->error);
    }

    if (!empty($params)) {
        $count_stmt->bind_param($types, ...$params);
    }
    $count_stmt->execute();
    $count_result = $count_stmt->get_result();
    $total_records = $count_result->fetch_assoc()['total'];

    error_log("get_staff.php - Total records found: $total_records");

    // === AGREGAR ORDENAMIENTO Y LÍMITE ===
    $sql .= " ORDER BY s.{$sort_by} {$sort_order}";
    $sql .= " LIMIT ? OFFSET ?";

    // Agregar parámetros de límite
    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    // === EJECUTAR CONSULTA PRINCIPAL ===
    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Error preparando consulta principal: " . $conn->error);
    }

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    // === PROCESAR RESULTADOS ===
    $staff_list = [];
    while ($row = $result->fetch_assoc()) {
        // ✅ ASEGURAR TIPOS DE DATOS CORRECTOS
        $row['id'] = intval($row['id']);
        $row['department_id'] = intval($row['department_id']);
        $row['position_id'] = intval($row['position_id']);
        $row['id_especialidad'] = $row['id_especialidad'] ? intval($row['id_especialidad']) : null;
        $row['salary'] = $row['salary'] ? floatval($row['salary']) : null;
        $row['is_active'] = boolval($row['is_active']);
        $row['has_photo'] = boolval($row['has_photo']);
        $row['has_emergency_contact'] = boolval($row['has_emergency_contact']);
        $row['years_employed'] = intval($row['years_employed']);

        // ✅ ASEGURAR CAMPOS NO NULL PARA JSON
        $row['staff_code'] = $row['staff_code'] ?: 'EMP-' . str_pad($row['id'], 4, '0', STR_PAD_LEFT);
        $row['phone'] = $row['phone'] ?: null;
        $row['birth_date'] = $row['birth_date'] ?: null;
        $row['address'] = $row['address'] ?: null;
        $row['emergency_contact_name'] = $row['emergency_contact_name'] ?: null;
        $row['emergency_contact_phone'] = $row['emergency_contact_phone'] ?: null;
        $row['photo_url'] = $row['photo_url'] ?: null;

        $staff_list[] = $row;
    }

    error_log("get_staff.php - Staff processed: " . count($staff_list));

    // === CALCULAR ESTADÍSTICAS ===
    $active_count = count(array_filter($staff_list, function ($staff) {
        return $staff['is_active'];
    }));
    $inactive_count = count($staff_list) - $active_count;
    $staff_with_salary = count(array_filter($staff_list, function ($staff) {
        return $staff['salary'] !== null;
    }));
    $average_salary = $staff_with_salary > 0 ? array_sum(array_column(array_filter($staff_list, function ($staff) {
        return $staff['salary'] !== null;
    }), 'salary')) / $staff_with_salary : 0;

    // === CALCULAR INFORMACIÓN DE PAGINACIÓN ===
    $total_pages = ceil($total_records / $limit);
    $current_page = floor($offset / $limit) + 1;

    // ✅ RESPUESTA EXITOSA CON LOGGING
    http_response_code(200);

    $response = [
        'success' => true,
        'message' => 'Empleados obtenidos exitosamente',
        'data' => [
            'staff' => $staff_list,
            'pagination' => [
                'current_page' => $current_page,
                'total_pages' => intval($total_pages),
                'total_records' => intval($total_records),
                'limit' => $limit,
                'offset' => $offset,
                'has_next' => $current_page < $total_pages,
                'has_previous' => $current_page > 1
            ],
            'summary' => [
                'total_returned' => count($staff_list),
                'active_staff' => $active_count,
                'inactive_staff' => $inactive_count,
                'staff_with_salary' => $staff_with_salary,
                'average_salary' => $average_salary,
                'filters_applied' => !empty($where_conditions)
            ]
        ],
        'filters_applied' => [
            'search' => $search,
            'department_id' => $department_id,
            'position_id' => $position_id,
            'is_active' => $is_active,
            'include_inactive' => $include_inactive,
            'hire_date_from' => $hire_date_from,
            'hire_date_to' => $hire_date_to,
            'salary_min' => $salary_min,
            'salary_max' => $salary_max,
            'identification_type' => $identification_type,
            'sort_by' => $sort_by,
            'sort_order' => $sort_order
        ]
    ];

    error_log("get_staff.php - Response prepared, outputting JSON");

    echo json_encode($response, JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
    // ✅ ERROR LOGGING Y RESPUESTA MEJORADA
    error_log("get_staff.php - Exception: " . $e->getMessage());

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error interno del servidor',
        'errors' => ['general' => $e->getMessage()],
        'debug_info' => [
            'file' => $e->getFile(),
            'line' => $e->getLine(),
            'trace' => $e->getTraceAsString()
        ]
    ], JSON_UNESCAPED_UNICODE);
}

// Cerrar conexión
if (isset($conn)) {
    $conn->close();
}

error_log("get_staff.php - Script execution completed");
