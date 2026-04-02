<?php
// check_updates.php - Endpoint ligero para Polling
// Permite al cliente verificar si hay cambios sin conectar WebSocket

require_once '../login/auth_middleware.php';

// Configurar CORS
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

try {
    // Autenticación opcional para no bloquear el chequeo ligero si el token expira
    // Pero idealmente debería ser requireAuth() si es info sensible.
    // Usaremos requireAuth para mantener seguridad, el cliente debe renovar token.
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['success' => false, 'message' => 'Unauthorized']);
    exit;
}

require '../conexion.php';

try {
    // Obtener el timestamp que envía el cliente (última vez que chequeó)
    // Se espera en formato ISO 8601 o timestamp UNIX, o MySQL datetime
    $last_check = isset($_GET['last_check']) ? $_GET['last_check'] : null;

    if (!$last_check) {
        // Si no envía fecha, asumimos que quiere el estado actual
        $last_check = date('Y-m-d H:i:s', strtotime('-1 minute')); // Default pequeño
    }

    // 1. Verificar tabla SERVICIOS (que tiene created_at y updated_at)
    // Buscamos si hay algún registro modificado DESPUÉS del last_check

    // Consulta optimizada para ser muy rápida
    $sql = "SELECT 
                COUNT(*) as count, 
                MAX(fecha_actualizacion) as max_updated,
                MAX(fecha_registro) as max_created
            FROM servicios 
            WHERE fecha_actualizacion > ? OR fecha_registro > ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ss", $last_check, $last_check);
    $stmt->execute();
    $result = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    $has_updates = $result['count'] > 0;

    // Determinar el nuevo timestamp de sincronización (el mayor encontrado o el actual)
    $server_time = date('Y-m-d H:i:s');
    $db_max_time = max($result['max_updated'] ?? '', $result['max_created'] ?? '');

    // Si hubo cambios, el sync_time es el de la DB, sino mantenemos el del servidor
    // Para evitar perder actualizaciones en el mismo segundo, usamos el tiempo del servidor actual
    $new_sync_time = $server_time;

    echo json_encode([
        'success' => true,
        'has_updates' => $has_updates,
        'update_count' => (int) $result['count'],
        'server_time' => $server_time,
        'sync_timestamp' => $new_sync_time,
        'debug_last_check' => $last_check
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error: ' . $e->getMessage()]);
}

if (isset($conn))
    $conn->close();
?>