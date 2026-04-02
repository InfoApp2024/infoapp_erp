<?php
// backend/notas/listar.php
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    if (!isset($_GET['id_servicio'])) {
        sendJsonResponse(errorResponse('ID de servicio requerido'), 400);
    }

    require '../conexion.php';

    $id_servicio = intval($_GET['id_servicio']);

    $stmt = $conn->prepare("SELECT * FROM notas WHERE id_servicio = ? ORDER BY created_at DESC");
    $stmt->bind_param("i", $id_servicio);
    $stmt->execute();
    $result = $stmt->get_result();
    
    $notas = [];
    while ($row = $result->fetch_assoc()) {
        // Convertir usuario_id a int para comparaciones en frontend
        $row['usuario_id'] = intval($row['usuario_id']);
        $row['id'] = intval($row['id']);
        $row['id_servicio'] = intval($row['id_servicio']);
        $notas[] = $row;
    }

    sendJsonResponse([
        'success' => true,
        'data' => $notas
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
