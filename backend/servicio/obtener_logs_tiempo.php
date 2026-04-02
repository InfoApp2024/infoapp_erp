<?php
// backend/servicio/obtener_logs_tiempo.php
require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación
    $currentUser = requireAuth();

    // 2. Conexión a BD
    require '../conexion.php';

    // 3. Obtener servicio_id del GET
    $servicio_id = $_GET['servicio_id'] ?? null;
    if (!$servicio_id) {
        throw new Exception('ID del servicio es requerido');
    }

    // 4. Query para obtener los logs de tiempo con nombres de estados y usuarios
    $sql = "
        SELECT 
            sl.id,
            sl.servicio_id,
            sl.from_status_id,
            ep_from.nombre_estado as from_status_name,
            sl.to_status_id,
            ep_to.nombre_estado as to_status_name,
            sl.user_id,
            u.NOMBRE_USER as user_name,
            sl.duration_seconds,
            sl.timestamp,
            sl.created_at
        FROM servicios_logs sl
        LEFT JOIN estados_proceso ep_from ON sl.from_status_id = ep_from.id
        INNER JOIN estados_proceso ep_to ON sl.to_status_id = ep_to.id
        INNER JOIN usuarios u ON sl.user_id = u.id
        WHERE sl.servicio_id = ?
        ORDER BY sl.timestamp ASC, sl.id ASC
    ";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $logs = [];
    while ($row = $result->fetch_assoc()) {
        // Formatear para el modelo ServiceTimeLogModel de Flutter
        $logs[] = [
            'id' => (int) $row['id'],
            'service_id' => (int) $row['servicio_id'],
            'from_status_id' => $row['from_status_id'] !== null ? (int) $row['from_status_id'] : null,
            'from_status_name' => $row['from_status_name'],
            'to_status_id' => (int) $row['to_status_id'],
            'to_status_name' => $row['to_status_name'],
            'user_id' => (int) $row['user_id'],
            'user_name' => $row['user_name'],
            'duration_seconds' => (int) $row['duration_seconds'],
            'timestamp' => $row['timestamp'],
            'created_at' => $row['created_at']
        ];
    }
    $stmt->close();

    // 5. Respuesta exitosa
    sendJsonResponse([
        'success' => true,
        'message' => 'Logs de tiempo obtenidos correctamente',
        'data' => $logs
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($conn))
        $conn->close();
}
?>