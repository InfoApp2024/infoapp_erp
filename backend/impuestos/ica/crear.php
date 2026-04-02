<?php
// crear.php - Crear tarifa ICA
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'impuestos/ica/crear.php', 'create_ica_tariff');

    require '../../conexion.php';
    $conn->set_charset("utf8mb4");

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input)
        throw new Exception("No se recibieron datos.");

    $ciudad_id = isset($input['ciudad_id']) ? (int) $input['ciudad_id'] : 0;
    $tarifa_x_mil = isset($input['tarifa_x_mil']) ? (float) $input['tarifa_x_mil'] : 0;
    $base_minima_uvt = isset($input['base_minima_uvt']) ? (float) $input['base_minima_uvt'] : 0;

    if ($ciudad_id <= 0)
        throw new Exception("La ciudad es requerida.");

    // Verificar si ya existe una tarifa para esta ciudad
    $stCheck = $conn->prepare("SELECT id FROM cnf_tarifas_ica WHERE ciudad_id = ?");
    $stCheck->bind_param("i", $ciudad_id);
    $stCheck->execute();
    if ($stCheck->get_result()->num_rows > 0) {
        throw new Exception("Ya existe una tarifa configurada para esta ciudad.");
    }
    $stCheck->close();

    $sql = "INSERT INTO cnf_tarifas_ica (ciudad_id, tarifa_x_mil, base_minima_uvt) VALUES (?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("idd", $ciudad_id, $tarifa_x_mil, $base_minima_uvt);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(['id' => $conn->insert_id], 'Tarifa ICA creada correctamente.'));
    } else {
        throw new Exception("Error al insertar en la base de datos.");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
?>