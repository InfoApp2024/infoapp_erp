<?php
// listar.php - Listar todas las especialidades
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $sql = "SELECT * FROM especialidades ORDER BY nom_especi ASC";
    $result = $conn->query($sql);

    $data = [];
    while ($row = $result->fetch_assoc()) {
        $row['valor_hr'] = (float)$row['valor_hr'];
        $data[] = $row;
    }

    sendJsonResponse(successResponse($data));

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
