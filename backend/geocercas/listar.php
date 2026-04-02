<?php
// backend/geocercas/listar.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    require '../conexion.php';

    // Listar todas las geocercas activas
    $sql = "SELECT * FROM geocercas WHERE estado = 1 ORDER BY id DESC";
    $result = $conn->query($sql);

    $geocercas = [];
    while ($row = $result->fetch_assoc()) {
        // Convertir tipos numéricos
        $row['id'] = (int)$row['id'];
        $row['latitud'] = (float)$row['latitud'];
        $row['longitud'] = (float)$row['longitud'];
        $row['radio'] = (int)$row['radio'];
        $row['estado'] = (int)$row['estado'];
        $geocercas[] = $row;
    }

    sendJsonResponse([
        'success' => true,
        'data' => $geocercas
    ]);

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
