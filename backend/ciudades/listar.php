<?php
// listar.php - Listar ciudades
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    // Verificar autenticación
    $currentUser = requireAuth();

    require '../conexion.php';

    // Parámetros de búsqueda
    $search = isset($_GET['search']) ? trim($_GET['search']) : '';
    $departamento_id = isset($_GET['departamento_id']) ? (int) $_GET['departamento_id'] : 0;

    $sql = "SELECT id, nombre, departamento, departamento_id FROM ciudades WHERE 1=1";
    $params = [];
    $types = "";

    if ($departamento_id > 0) {
        $sql .= " AND departamento_id = ?";
        $params[] = $departamento_id;
        $types .= "i";
    }

    if (!empty($search)) {
        $sql .= " AND (nombre LIKE ? OR departamento LIKE ?)";
        $searchTerm = "%{$search}%";
        $params[] = $searchTerm;
        $params[] = $searchTerm;
        $types .= "ss";
    }

    $sql .= " ORDER BY nombre ASC";

    $stmt = $conn->prepare($sql);
    if (!empty($params)) {
        $stmt->bind_param($types, ...$params);
    }
    $stmt->execute();
    $result = $stmt->get_result();

    $ciudades = [];
    while ($row = $result->fetch_assoc()) {
        $ciudades[] = $row;
    }

    sendJsonResponse(successResponse($ciudades));

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
