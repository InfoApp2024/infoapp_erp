<?php
/**
 * get_snapshot_history.php
 * Retorna el historial de ajustes financieros para un servicio específico con timestamps exactos.
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $servicio_id = $_GET['servicio_id'] ?? null;

    if (!$servicio_id) {
        throw new Exception("ID del servicio es requerido.");
    }

    $sql = "SELECT a.*, u.NOMBRE_USER as usuario_nombre 
            FROM fac_snapshot_ajustes a
            JOIN usuarios u ON a.usuario_id = u.id
            WHERE a.servicio_id = ?
            ORDER BY a.fecha DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $history = $result->fetch_all(MYSQLI_ASSOC);
    $stmt->close();

    echo json_encode([
        'success' => true,
        'data' => $history
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}
