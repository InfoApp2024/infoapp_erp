<?php
/**
 * get_factus_settings.php
 * Obtiene la configuración de Factus almacenada en app_settings.
 */

define('AUTH_REQUIRED', true);
require_once '../login/auth_middleware.php';

try {
    requireAuth();
    require '../conexion.php';

    $keys = [
        'factus_client_id',
        'factus_client_secret',
        'factus_username',
        'factus_password',
        'factus_numbering_range_id'
    ];

    $placeholders = implode(',', array_fill(0, count($keys), '?'));
    $sql = "SELECT setting_key, setting_value FROM app_settings WHERE setting_key IN ($placeholders)";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param(str_repeat('s', count($keys)), ...$keys);
    $stmt->execute();
    $result = $stmt->get_result();

    $settings = [];
    while ($row = $result->fetch_assoc()) {
        $settings[$row['setting_key']] = $row['setting_value'];
    }
    $stmt->close();

    // Asegurar que todos los campos existan en la respuesta (aunque sean vacíos)
    foreach ($keys as $key) {
        if (!isset($settings[$key])) {
            $settings[$key] = '';
        }
    }

    sendJsonResponse([
        'success' => true,
        'data' => $settings
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
