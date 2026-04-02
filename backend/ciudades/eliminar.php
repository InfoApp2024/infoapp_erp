<?php
// eliminar.php - Eliminar ciudad
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    // Idealmente solo admin debería poder borrar ciudades maestras
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['id'])) {
        throw new Exception('ID de ciudad requerido');
    }

    $id = (int)$input['id'];

    // Verificar si la ciudad está en uso por algún cliente
    $stmtCheck = $conn->prepare("SELECT id FROM clientes WHERE ciudad_id = ? LIMIT 1");
    $stmtCheck->bind_param("i", $id);
    $stmtCheck->execute();
    if ($stmtCheck->get_result()->num_rows > 0) {
        throw new Exception('No se puede eliminar la ciudad porque tiene clientes asociados');
    }
    
    // También verificar si está en uso por equipos (si aplica, según tu esquema actual equipos tiene campo ciudad pero parece ser texto, 
    // pero si en el futuro lo enlazas, deberías validarlo aquí también. 
    // Por ahora validamos clientes que es la relación FK explícita que acabamos de crear)

    $stmt = $conn->prepare("DELETE FROM ciudades WHERE id = ?");
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        if ($stmt->affected_rows === 0) {
            throw new Exception('Ciudad no encontrada');
        }
        sendJsonResponse(successResponse(null, 'Ciudad eliminada correctamente'));
    } else {
        throw new Exception('Error al eliminar la ciudad');
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
