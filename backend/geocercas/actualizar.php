<?php
// backend/geocercas/actualizar.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    require '../conexion.php';

    $data = json_decode(file_get_contents("php://input"), true);

    if (!isset($data['id'])) {
        throw new Exception("ID de geocerca requerido");
    }

    $id = intval($data['id']);
    $nombre = isset($data['nombre']) ? trim($data['nombre']) : null;
    $latitud = isset($data['latitud']) ? floatval($data['latitud']) : null;
    $longitud = isset($data['longitud']) ? floatval($data['longitud']) : null;
    $radio = isset($data['radio']) ? intval($data['radio']) : null;

    // Construir query dinámicamente
    $updates = [];
    $types = "";
    $params = [];

    if ($nombre !== null) {
        $updates[] = "nombre = ?";
        $types .= "s";
        $params[] = $nombre;
    }
    if ($latitud !== null) {
        $updates[] = "latitud = ?";
        $types .= "d";
        $params[] = $latitud;
    }
    if ($longitud !== null) {
        $updates[] = "longitud = ?";
        $types .= "d";
        $params[] = $longitud;
    }
    if ($radio !== null) {
        $updates[] = "radio = ?";
        $types .= "i";
        $params[] = $radio;
    }

    if (empty($updates)) {
        throw new Exception("No hay datos para actualizar");
    }

    $sql = "UPDATE geocercas SET " . implode(", ", $updates) . " WHERE id = ?";
    $types .= "i";
    $params[] = $id;

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);

    if ($stmt->execute()) {
        sendJsonResponse([
            'success' => true,
            'message' => 'Geocerca actualizada exitosamente'
        ]);
    } else {
        throw new Exception("Error al actualizar: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
