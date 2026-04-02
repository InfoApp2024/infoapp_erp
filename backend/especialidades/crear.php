<?php
// crear.php - Crear nueva especialidad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (empty($input['nom_especi'])) {
        throw new Exception('El nombre de la especialidad es obligatorio');
    }

    $nom_especi = trim($input['nom_especi']);
    $valor_hr = isset($input['valor_hr']) ? (float)$input['valor_hr'] : 0.00;

    $stmt = $conn->prepare("INSERT INTO especialidades (nom_especi, valor_hr) VALUES (?, ?)");
    $stmt->bind_param("sd", $nom_especi, $valor_hr);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse([
            'id' => $stmt->insert_id,
            'nom_especi' => $nom_especi,
            'valor_hr' => $valor_hr
        ], 'Especialidad creada exitosamente'));
    } else {
        throw new Exception("Error al crear especialidad: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
