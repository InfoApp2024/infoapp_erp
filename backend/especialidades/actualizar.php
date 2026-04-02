<?php
// actualizar.php - Actualizar especialidad
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

  if (empty($input['id'])) {
    throw new Exception('ID requerido');
  }

  $id = (int)$input['id'];
  $nom_especi = isset($input['nom_especi']) ? trim($input['nom_especi']) : null;
  $valor_hr = isset($input['valor_hr']) ? (float)$input['valor_hr'] : null;

  $fields = [];
  $types = "";
  $params = [];

  if ($nom_especi !== null) {
    $fields[] = "nom_especi = ?";
    $types .= "s";
    $params[] = $nom_especi;
  }

  if ($valor_hr !== null) {
    $fields[] = "valor_hr = ?";
    $types .= "d";
    $params[] = $valor_hr;
  }

  if (empty($fields)) {
    throw new Exception('No hay datos para actualizar');
  }

  $sql = "UPDATE especialidades SET " . implode(", ", $fields) . " WHERE id = ?";
  $types .= "i";
  $params[] = $id;

  $stmt = $conn->prepare($sql);
  $stmt->bind_param($types, ...$params);

  if ($stmt->execute()) {
    sendJsonResponse(successResponse(null, 'Especialidad actualizada'));
  } else {
    throw new Exception("Error al actualizar: " . $stmt->error);
  }
} catch (Exception $e) {
  sendJsonResponse(errorResponse($e->getMessage()), 500);
}
