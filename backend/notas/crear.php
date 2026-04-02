<?php
// backend/notas/crear.php
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    $input = json_decode(file_get_contents('php://input'), true);

    if (!isset($input['id_servicio']) || !isset($input['nota'])) {
        sendJsonResponse(errorResponse('Faltan datos requeridos'), 400);
    }

    require '../conexion.php';

    // Establecer zona horaria a Colombia/Perú/Ecuador (UTC-5)
    date_default_timezone_set('America/Bogota');

    $id_servicio = intval($input['id_servicio']);
    $nota = trim($input['nota']);
    $fecha = date('Y-m-d');
    $hora = date('H:i:s');
    $usuario = $currentUser['usuario'];
    $usuario_id = intval($currentUser['id']);

    $stmt = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id) VALUES (?, ?, ?, ?, ?, ?)");
    $stmt->bind_param("issssi", $id_servicio, $nota, $fecha, $hora, $usuario, $usuario_id);

    if ($stmt->execute()) {
        $id = $stmt->insert_id;
        sendJsonResponse([
            'success' => true,
            'message' => 'Nota creada exitosamente',
            'data' => [
                'id' => $id,
                'id_servicio' => $id_servicio,
                'nota' => $nota,
                'fecha' => $fecha,
                'hora' => $hora,
                'usuario' => $usuario,
                'usuario_id' => $usuario_id
            ]
        ]);
    } else {
        throw new Exception("Error al crear la nota: " . $stmt->error);
    }
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
