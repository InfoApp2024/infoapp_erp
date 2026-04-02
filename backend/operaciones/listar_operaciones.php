<?php
// backend/operaciones/listar_operaciones.php
require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación JWT
    $currentUser = requireAuth();

    // 2. Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // 3. Obtener parámetros
    if (!isset($_GET['servicio_id'])) {
        sendJsonResponse(errorResponse('ID de servicio no proporcionado'), 400);
    }
    $servicio_id = intval($_GET['servicio_id']);

    // 4. Conexión a BD
    require '../conexion.php';

    // 5. Consultar operaciones
    $sql = "SELECT o.*, u.NOMBRE_USER as tecnico_nombre, ae.actividad as actividad_nombre
            FROM operaciones o
            LEFT JOIN usuarios u ON o.tecnico_responsable_id = u.id
            LEFT JOIN actividades_estandar ae ON o.actividad_estandar_id = ae.id
            WHERE o.servicio_id = ?
            ORDER BY o.created_at ASC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $operaciones = [];
    while ($row = $result->fetch_assoc()) {
        $operaciones[] = $row;
    }

    sendJsonResponse(successResponse($operaciones));

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error al listar operaciones: ' . $e->getMessage()), 500);
}
?>