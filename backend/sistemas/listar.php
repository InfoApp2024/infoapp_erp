<?php
// sistemas/listar.php - Listar sistemas - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/sistemas/listar.php', 'view_systems');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $activo = isset($_GET['activo']) ? (int) $_GET['activo'] : null;
    $buscar = isset($_GET['buscar']) ? trim($_GET['buscar']) : '';

    // Construir WHERE clause
    $whereConditions = [];
    $params = [];
    $types = "";

    if ($activo !== null) {
        $whereConditions[] = "activo = ?";
        $params[] = $activo;
        $types .= "i";
    }

    if (!empty($buscar)) {
        $whereConditions[] = "(nombre LIKE ? OR descripcion LIKE ?)";
        $searchTerm = "%$buscar%";
        $params = array_merge($params, [$searchTerm, $searchTerm]);
        $types .= "ss";
    }

    $whereClause = !empty($whereConditions) ? "WHERE " . implode(" AND ", $whereConditions) : "";

    $sql = "SELECT id, nombre, descripcion, activo, created_at, updated_at 
            FROM sistemas 
            $whereClause 
            ORDER BY nombre ASC";

    $stmt = $conn->prepare($sql);

    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $sistemas = [];

    while ($row = $result->fetch_assoc()) {
        $sistemas[] = [
            'id' => (int) $row['id'],
            'nombre' => $row['nombre'],
            'descripcion' => $row['descripcion'] ?? '',
            'activo' => (bool) $row['activo'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at']
        ];
    }

    sendJsonResponse([
        'success' => true,
        'data' => $sistemas,
        'total' => count($sistemas)
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>