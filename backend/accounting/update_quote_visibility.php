<?php
/**
 * update_quote_visibility.php
 * Actualiza el flag ver_detalle_cotizacion en fac_control_servicios.
 */
require_once '../login/auth_middleware.php';
define('AUTH_REQUIRED', true);

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    $data = json_decode(file_get_contents('php://input'), true);
    $servicio_id = $data['servicio_id'] ?? null;
    $ver_detalle = isset($data['ver_detalle']) ? (int) $data['ver_detalle'] : null;

    if (!$servicio_id || $ver_detalle === null) {
        throw new Exception("Datos incompletos.");
    }

    $stmt = $conn->prepare("UPDATE fac_control_servicios SET ver_detalle_cotizacion = ? WHERE servicio_id = ?");
    $stmt->bind_param("ii", $ver_detalle, $servicio_id);

    if ($stmt->execute()) {
        echo json_encode(['success' => true, 'message' => 'Preferencia de visibilidad actualizada.']);
    } else {
        throw new Exception("Error al actualizar la base de datos.");
    }
    $stmt->close();

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
} finally {
    if (isset($conn))
        $conn->close();
}
