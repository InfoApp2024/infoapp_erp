<?php
require_once __DIR__ . '/../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET');

require '../conexion.php'; // Usamos $conn (MySQLi)

try {
    $currentUser = requireAuth();

    // Validar permiso
    requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'ver', $currentUser['rol']);

    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;

    if ($id <= 0) {
        throw new Exception('ID de actividad inválido');
    }

    $sql = "SELECT 
                id,
                actividad,
                activo,
                cant_hora,
                num_tecnicos,
                id_user,
                sistema_id,
                created_at,
                updated_at
            FROM actividades_estandar
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $actividad = $result->fetch_assoc();

    if (!$actividad) {
        http_response_code(404);
        echo json_encode([
            'success' => false,
            'message' => 'Actividad no encontrada'
        ]);
        exit;
    }

    // Convertir tipos de datos
    $actividad['id'] = (int) $actividad['id'];
    $actividad['activo'] = (bool) $actividad['activo'];
    $actividad['cant_hora'] = (float) $actividad['cant_hora'];
    $actividad['num_tecnicos'] = (int) $actividad['num_tecnicos'];
    $actividad['id_user'] = $actividad['id_user'] ? (int) $actividad['id_user'] : null;
    $actividad['sistema_id'] = $actividad['sistema_id'] ? (int) $actividad['sistema_id'] : null;

    echo json_encode([
        'success' => true,
        'data' => $actividad
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error al obtener actividad estándar',
        'error' => $e->getMessage()
    ]);
} finally {
    // Cerrar sentencia y conexión de forma segura
    if (isset($stmt) && is_object($stmt))
        $stmt->close();
    if (isset($conn) && $conn instanceof mysqli)
        $conn->close();
}
