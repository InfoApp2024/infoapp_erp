<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/listar_funcionarios.php', 'view_funcionarios');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';

    if (!$conn) {
        throw new Exception("Error de conexión a la base de datos");
    }

    // PASO 5: Parámetros de filtrado
    $empresa = isset($_GET['empresa']) ? trim($_GET['empresa']) : '';

    // 🆕 NUEVO: Filtro por cliente_id
    $cliente_id = isset($_GET['cliente_id']) ? (int) $_GET['cliente_id'] : null;

    // PASO 6: Consulta con manejo de errores
    $whereClause = "WHERE activo = 1";
    $params = [];
    $types = "";

    // Evitar filtrar por strings literales "null" o "undefined" que a veces envía el frontend
    if ($empresa === 'null' || $empresa === 'undefined') {
        $empresa = '';
    }

    // 🆕 NUEVO: Priorizar filtro por cliente_id si está presente
    if ($cliente_id !== null && $cliente_id > 0) {
        $whereClause .= " AND cliente_id = ?";
        $params[] = $cliente_id;
        $types .= "i";
    } elseif (!empty($empresa)) {
        // Mantener compatibilidad con filtro por texto de empresa
        $whereClause .= " AND empresa LIKE ?";
        $params[] = "%" . $empresa . "%";
        $types .= "s";
    }


    $sql = "SELECT id, nombre, cargo, empresa, telefono, correo, activo FROM funcionario $whereClause ORDER BY nombre";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    $stmt->execute();
    $result = $stmt->get_result();

    if (!$result) {
        // Fallback simplificado si la tabla principal falla
        $sql = "SELECT id, nombre, cargo, activo FROM empleados WHERE activo = 1 ORDER BY nombre";
        $result = $conn->query($sql);
        if (!$result) {
            throw new Exception("Error en la consulta SQL: " . $conn->error);
        }
    }

    // PASO 6: Procesar resultados
    $funcionarios = [];
    if ($result->num_rows > 0) {
        while ($row = $result->fetch_assoc()) {
            $funcionarios[] = [
                'id' => (int) $row['id'],
                'nombre' => $row['nombre'],
                'cargo' => $row['cargo'] ?? '',
                'empresa' => $row['empresa'] ?? '',
                'telefono' => $row['telefono'] ?? '',
                'correo' => $row['correo'] ?? '',
                'activo' => (int) ($row['activo'] ?? 1)
            ];
        }
    }

    error_log("DEBUG: Retornando " . count($funcionarios) . " funcionarios para usuario: " . $currentUser['usuario']);

    // PASO 7: Respuesta exitosa con contexto de usuario
    sendJsonResponse([
        'success' => true,
        'funcionarios' => $funcionarios,
        'debug_info' => [
            'empresa_filter' => $empresa,
            'count' => count($funcionarios),
            'sql_executed' => $sql
        ],
        'total' => count($funcionarios),
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);

} catch (Exception $e) {
    error_log("ERROR: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>