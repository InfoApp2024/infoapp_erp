<?php
// sistemas/actualizar.php - Actualizar sistema - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/sistemas/actualizar.php', 'update_system');

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $id = $input['id'] ?? null;
    $nombre = $input['nombre'] ?? null;
    $descripcion = $input['descripcion'] ?? null;
    $activo = isset($input['activo']) ? (int) $input['activo'] : null;

    if (!$id) {
        throw new Exception('ID del sistema requerido');
    }

    // Verificar que el sistema existe
    $stmt_check = $conn->prepare("SELECT id FROM sistemas WHERE id = ?");
    $stmt_check->bind_param("i", $id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows === 0) {
        throw new Exception('Sistema no encontrado');
    }
    $stmt_check->close();

    // Construir UPDATE dinámico
    $updates = [];
    $params = [];
    $types = "";

    if ($nombre !== null) {
        // Verificar que no exista otro sistema con el mismo nombre
        $stmt_dup = $conn->prepare("SELECT id FROM sistemas WHERE nombre = ? AND id != ?");
        $stmt_dup->bind_param("si", $nombre, $id);
        $stmt_dup->execute();
        $result_dup = $stmt_dup->get_result();

        if ($result_dup->num_rows > 0) {
            throw new Exception('Ya existe otro sistema con ese nombre');
        }
        $stmt_dup->close();

        $updates[] = "nombre = ?";
        $params[] = $nombre;
        $types .= "s";
    }

    if ($descripcion !== null) {
        $updates[] = "descripcion = ?";
        $params[] = $descripcion;
        $types .= "s";
    }

    if ($activo !== null) {
        $updates[] = "activo = ?";
        $params[] = $activo;
        $types .= "i";
    }

    if (empty($updates)) {
        throw new Exception('No hay campos para actualizar');
    }

    $sql = "UPDATE sistemas SET " . implode(", ", $updates) . " WHERE id = ?";
    $params[] = $id;
    $types .= "i";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);

    if (!$stmt->execute()) {
        throw new Exception('Error actualizando sistema: ' . $stmt->error);
    }

    sendJsonResponse([
        'success' => true,
        'message' => 'Sistema actualizado exitosamente',
        'data' => [
            'id' => (int) $id
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