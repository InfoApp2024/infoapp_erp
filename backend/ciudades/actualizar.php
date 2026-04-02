<?php
// actualizar.php - Actualizar ciudad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
  $currentUser = requireAuth();
  // Opcional: Validar rol admin si es necesario

  if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    sendJsonResponse(errorResponse('Método no permitido'), 405);
  }

  require '../conexion.php';

  $input = json_decode(file_get_contents('php://input'), true);

  if (!$input || !isset($input['id'])) {
    throw new Exception('ID de ciudad requerido');
  }

  $id = (int)$input['id'];
  $nombre = isset($input['nombre']) ? trim($input['nombre']) : '';
  $departamento = isset($input['departamento']) ? trim($input['departamento']) : '';

  if (empty($nombre) || empty($departamento)) {
    throw new Exception('Nombre y departamento son obligatorios');
  }

  // Verificar si existe otra ciudad con el mismo nombre/departamento
  $stmtCheck = $conn->prepare("SELECT id FROM ciudades WHERE nombre = ? AND departamento = ? AND id != ?");
  $stmtCheck->bind_param("ssi", $nombre, $departamento, $id);
  $stmtCheck->execute();
  if ($stmtCheck->get_result()->num_rows > 0) {
    throw new Exception('Ya existe otra ciudad con ese nombre en ese departamento');
  }

  $stmt = $conn->prepare("UPDATE ciudades SET nombre = ?, departamento = ? WHERE id = ?");
  $stmt->bind_param("ssi", $nombre, $departamento, $id);

  if ($stmt->execute()) {
    if ($stmt->affected_rows === 0) {
      // Puede ser que no se encontraron cambios o el ID no existe
      // Verificamos si existe el ID
      $checkId = $conn->query("SELECT id FROM ciudades WHERE id = $id");
      if ($checkId->num_rows === 0) {
        throw new Exception('Ciudad no encontrada');
      }
    }
    sendJsonResponse(successResponse(null, 'Ciudad actualizada correctamente'));
  } else {
    throw new Exception('Error al actualizar la ciudad');
  }
} catch (Exception $e) {
  sendJsonResponse(errorResponse($e->getMessage()), 500);
}
