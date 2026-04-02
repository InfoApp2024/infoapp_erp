<?php
/**
 * gestionar_causacion.php
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $sql = "SELECT c.*, p.nombre as cuenta_nombre, p.codigo_cuenta
                FROM fin_config_causacion c
                LEFT JOIN fin_puc p ON c.puc_cuenta_id = p.id
                WHERE c.activo = 1";
        $result = $conn->query($sql);
        sendJsonResponse(['success' => true, 'data' => $result->fetch_all(MYSQLI_ASSOC)]);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
