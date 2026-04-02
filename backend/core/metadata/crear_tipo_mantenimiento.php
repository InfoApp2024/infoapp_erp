<?php
require_once __DIR__ . '/../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require __DIR__ . '/../../conexion.php';

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Método no permitido');
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $tipo = isset($input['tipo']) ? trim($input['tipo']) : null;

    if (!$tipo) {
        throw new Exception('El tipo es requerido');
    }

    $stmt = $conn->prepare("INSERT IGNORE INTO tipos_mantenimiento (nombre) VALUES (?)");
    $stmt->bind_param("s", $tipo);
    
    if ($stmt->execute()) {
        sendJsonResponse([
            'success' => true,
            'message' => 'Tipo de mantenimiento creado exitosamente'
        ]);
    } else {
        throw new Exception($stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse(['success' => false,'message' => $e->getMessage()], 500);
} finally {
    if (isset($conn)) $conn->close();
}
?>
