<?php
// actualizar.php - Actualizar tarifa ICA
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/ica/actualizar.php', 'update_ica_tariff');

    require '../../conexion.php';
    $conn->set_charset("utf8mb4");

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input)
        throw new Exception("No se recibieron datos.");

    $id = isset($input['id']) ? (int) $input['id'] : 0;
    $ciudad_id = isset($input['ciudad_id']) ? (int) $input['ciudad_id'] : 0;
    $tarifa_x_mil = isset($input['tarifa_x_mil']) ? (float) $input['tarifa_x_mil'] : 0;
    $base_minima_uvt = isset($input['base_minima_uvt']) ? (float) $input['base_minima_uvt'] : 0;

    if ($id <= 0)
        throw new Exception("El ID de la tarifa es requerido.");
    if ($ciudad_id <= 0)
        throw new Exception("La ciudad es requerida.");

    // Verificar si la ciudad ya está en otra tarifa
    $stCheck = $conn->prepare("SELECT id FROM cnf_tarifas_ica WHERE ciudad_id = ? AND id != ?");
    $stCheck->bind_param("ii", $ciudad_id, $id);
    $stCheck->execute();
    if ($stCheck->get_result()->num_rows > 0) {
        throw new Exception("Otra tarifa ya está configurada para esta ciudad.");
    }
    $stCheck->close();

    $sql = "UPDATE cnf_tarifas_ica SET ciudad_id = ?, tarifa_x_mil = ?, base_minima_uvt = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iddi", $ciudad_id, $tarifa_x_mil, $base_minima_uvt, $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Tarifa ICA actualizada correctamente.'));
    } else {
        throw new Exception("Error al actualizar la base de datos.");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
?>