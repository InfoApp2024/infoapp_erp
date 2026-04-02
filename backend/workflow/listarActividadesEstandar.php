<?php
require_once __DIR__ . '/../login/auth_middleware.php';

// Configurar CORS y Auth
$currentUser = requireAuth();

// Doble verificación para preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

require_once __DIR__ . '/../conexion.php';

// Validar permiso
requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'listar', $currentUser['rol']);

try {
    $filtro_activo = isset($_GET['activo']) ? $_GET['activo'] : null;
    $busqueda = isset($_GET['busqueda']) ? $_GET['busqueda'] : '';

    $sql = "SELECT 
                ae.id,
                ae.actividad,
                ae.activo,
                ae.created_at,
                ae.updated_at,
                ae.cant_hora,
                ae.num_tecnicos,
                ae.id_user,
                ae.sistema_id,
                s.nombre as sistema_nombre
            FROM actividades_estandar ae
            LEFT JOIN sistemas s ON ae.sistema_id = s.id
            WHERE 1=1";

    $params = [];
    $types = "";

    // Filtro por estado activo
    if ($filtro_activo !== null) {
        $sql .= " AND ae.activo = ?";
        $params[] = $filtro_activo;
        $types .= "i";
    }

    // Búsqueda por nombre de actividad
    if (!empty($busqueda)) {
        $sql .= " AND ae.actividad LIKE ?";
        $params[] = "%$busqueda%";
        $types .= "s";
    }

    $sql .= " ORDER BY ae.actividad ASC";

    $stmt = $conn->prepare($sql);

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando consulta: " . $stmt->error);
    }

    $result = $stmt->get_result();

    $actividades = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['activo'] = (bool) $row['activo'];
        $row['cant_hora'] = (float) $row['cant_hora'];
        $row['num_tecnicos'] = (int) $row['num_tecnicos'];
        $row['id_user'] = $row['id_user'] ? (int) $row['id_user'] : null;
        $row['sistema_id'] = $row['sistema_id'] ? (int) $row['sistema_id'] : null;
        $row['sistema_nombre'] = $row['sistema_nombre'] ?? 'N/A';
        $actividades[] = $row;
    }

    $stmt->close();

    echo json_encode([
        'success' => true,
        'data' => $actividades,
        'total' => count($actividades)
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error al obtener actividades estándar',
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>