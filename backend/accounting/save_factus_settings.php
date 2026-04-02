<?php
/**
 * save_factus_settings.php
 * Guarda la configuración de Factus en app_settings.
 */

define('AUTH_REQUIRED', true);
require_once '../login/auth_middleware.php';

try {
    requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);

    if (!$data) {
        throw new Exception("No se recibieron datos.");
    }

    $valid_keys = [
        'factus_client_id',
        'factus_client_secret',
        'factus_username',
        'factus_password',
        'factus_numbering_range_id'
    ];

    $conn->begin_transaction();

    $stmt = $conn->prepare("INSERT INTO app_settings (setting_key, setting_value, description) VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value), updated_at = CURRENT_TIMESTAMP");

    foreach ($data as $key => $value) {
        if (in_array($key, $valid_keys)) {
            $description = "Factus " . str_replace('factus_', '', $key);
            $stmt->bind_param("sss", $key, $value, $description);
            $stmt->execute();
        }
    }

    $stmt->close();
    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => 'Configuración de Factus guardada correctamente.'
    ]);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
