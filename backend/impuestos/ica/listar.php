<?php
// listar.php - Listar tarifas ICA por ciudad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/ica/listar.php', 'list_ica_tariffs');

    require '../../conexion.php';
    $conn->set_charset("utf8mb4");

    $sql = "SELECT t.id, t.ciudad_id, t.tarifa_x_mil, t.base_minima_uvt, c.nombre as ciudad_nombre 
          FROM cnf_tarifas_ica t
          JOIN ciudades c ON t.ciudad_id = c.id
          ORDER BY c.nombre ASC";

    $stmt = $conn->prepare($sql);
    $stmt->execute();
    $result = $stmt->get_result();

    $data = [];
    while ($row = $result->fetch_assoc()) {
        $row['id'] = (int) $row['id'];
        $row['ciudad_id'] = (int) $row['ciudad_id'];
        $row['tarifa_x_mil'] = (float) $row['tarifa_x_mil'];
        $row['base_minima_uvt'] = (float) $row['base_minima_uvt'];
        $data[] = $row;
    }

    sendJsonResponse(successResponse($data));
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
?>