<?php
// sistemas/eliminar.php - Eliminar sistema - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/sistemas/eliminar.php', 'delete_system');

    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $id = $input['id'] ?? null;

    if (!$id) {
        throw new Exception('ID del sistema requerido');
    }

    // Verificar que el sistema existe
    $stmt_check = $conn->prepare("SELECT nombre FROM sistemas WHERE id = ?");
    $stmt_check->bind_param("i", $id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        throw new Exception('Sistema no encontrado');
    }

    $sistema = $result_check->fetch_assoc();
    $nombre = $sistema['nombre'];
    $stmt_check->close();

    // Verificar si el sistema está en uso
    $stmt_uso = $conn->prepare("SELECT COUNT(*) as count FROM inspecciones_sistemas WHERE sistema_id = ?");
    $stmt_uso->bind_param("i", $id);
    $stmt_uso->execute();
    $result_uso = $stmt_uso->get_result();
    $row_uso = $result_uso->fetch_assoc();

    if ($row_uso['count'] > 0) {
        throw new Exception('No se puede eliminar el sistema porque está siendo utilizado en ' . $row_uso['count'] . ' inspección(es)');
    }
    $stmt_uso->close();

    // Eliminar sistema
    $sql = "DELETE FROM sistemas WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if (!$stmt->execute()) {
        throw new Exception('Error eliminando sistema: ' . $stmt->error);
    }

    sendJsonResponse([
        'success' => true,
        'message' => 'Sistema eliminado exitosamente',
        'data' => [
            'id' => (int) $id,
            'nombre' => $nombre
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>