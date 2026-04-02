<?php
// crear.php - Crear nueva ciudad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    // Verificar autenticación
    $currentUser = requireAuth();
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Datos inválidos');
    }

    $nombre = isset($input['nombre']) ? trim($input['nombre']) : '';
    $departamento = isset($input['departamento']) ? trim($input['departamento']) : '';

    if (empty($nombre) || empty($departamento)) {
        throw new Exception('Nombre y departamento son obligatorios');
    }

    // Verificar si ya existe
    $stmtCheck = $conn->prepare("SELECT id FROM ciudades WHERE nombre = ? AND departamento = ?");
    $stmtCheck->bind_param("ss", $nombre, $departamento);
    $stmtCheck->execute();
    if ($stmtCheck->get_result()->num_rows > 0) {
        throw new Exception('La ciudad ya existe en ese departamento');
    }

    $stmt = $conn->prepare("INSERT INTO ciudades (nombre, departamento) VALUES (?, ?)");
    $stmt->bind_param("ss", $nombre, $departamento);
    
    if ($stmt->execute()) {
        sendJsonResponse(successResponse([
            'id' => $stmt->insert_id,
            'nombre' => $nombre,
            'departamento' => $departamento
        ], 'Ciudad creada correctamente'));
    } else {
        throw new Exception('Error al crear la ciudad');
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
