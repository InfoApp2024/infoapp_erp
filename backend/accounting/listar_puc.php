<?php
/**
 * listar_puc.php
 * Retorna el catálogo de cuentas (PUC)
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $sql = "SELECT codigo, nombre, tipo FROM fin_puc ORDER BY codigo ASC";
    $result = $conn->query($sql);

    $puc = [];
    while ($row = $result->fetch_assoc()) {
        $puc[] = $row;
    }

    sendJsonResponse([
        'success' => true,
        'data' => $puc
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
