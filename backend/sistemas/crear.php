<?php
// sistemas/crear.php - Crear nuevo sistema - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/sistemas/crear.php', 'create_system');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $nombre = $input['nombre'] ?? null;
    $descripcion = $input['descripcion'] ?? '';
    $activo = isset($input['activo']) ? (int) $input['activo'] : 1;

    if (!$nombre) {
        throw new Exception('Nombre del sistema requerido');
    }

    // Verificar que no exista un sistema con el mismo nombre
    $stmt_check = $conn->prepare("SELECT id FROM sistemas WHERE nombre = ?");
    $stmt_check->bind_param("s", $nombre);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();

    if ($result_check->num_rows > 0) {
        throw new Exception('Ya existe un sistema con ese nombre');
    }
    $stmt_check->close();

    // Insertar sistema
    $sql = "INSERT INTO sistemas (nombre, descripcion, activo) VALUES (?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssi", $nombre, $descripcion, $activo);

    if (!$stmt->execute()) {
        throw new Exception('Error creando sistema: ' . $stmt->error);
    }

    $sistema_id = $conn->insert_id;

    sendJsonResponse([
        'success' => true,
        'message' => 'Sistema creado exitosamente',
        'data' => [
            'id' => (int) $sistema_id,
            'nombre' => $nombre,
            'descripcion' => $descripcion,
            'activo' => (bool) $activo
        ]
    ], 201);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>