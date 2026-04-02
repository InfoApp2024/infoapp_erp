<?php
// backend/geocercas/crear.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth(); // Solo usuarios autenticados
    
    // Validar permisos (opcional: solo admin puede crear geocercas)
    // if ($currentUser['rol'] !== 'administrador') { ... }

    require '../conexion.php';

    // Obtener datos del cuerpo de la solicitud
    $data = json_decode(file_get_contents("php://input"), true);

    if (!isset($data['nombre']) || !isset($data['latitud']) || !isset($data['longitud'])) {
        throw new Exception("Faltan datos obligatorios (nombre, latitud, longitud)");
    }

    $nombre = trim($data['nombre']);
    $latitud = floatval($data['latitud']);
    $longitud = floatval($data['longitud']);
    $radio = isset($data['radio']) ? intval($data['radio']) : 100; // Default 100m
    $estado = 1;

    // Insertar en base de datos
    $sql = "INSERT INTO geocercas (nombre, latitud, longitud, radio, estado) VALUES (?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sddii", $nombre, $latitud, $longitud, $radio, $estado);

    if ($stmt->execute()) {
        sendJsonResponse([
            'success' => true,
            'message' => 'Geocerca creada exitosamente',
            'id' => $stmt->insert_id
        ]);
    } else {
        throw new Exception("Error al crear la geocerca: " . $stmt->error);
    }

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
