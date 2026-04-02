<?php
/**
 * departamentos/listar.php
 * Lista todos los departamentos disponibles.
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $sql = "SELECT id, nombre FROM departamentos ORDER BY nombre ASC";
    $result = $conn->query($sql);

    $departamentos = [];
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            $departamentos[] = $row;
        }
    }

    sendJsonResponse(successResponse($departamentos));

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
?>