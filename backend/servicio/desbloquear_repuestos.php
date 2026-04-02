<?php
require_once '../login/auth_middleware.php';

try {
    // 1. Authenticate & CORS
    // requireAuth() handles token validation and automatic CORS headers
    $currentUser = requireAuth();
    $userId = intval($currentUser['id']);

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido', 405), 405);
    }

    require '../conexion.php';

    // 2. Check Permission
    $sqlPerm = "SELECT 1 FROM user_permissions WHERE user_id = ? AND module = 'servicios_repuestos' AND action = 'desbloquear'";
    $stmtPerm = $conn->prepare($sqlPerm);
    if (!$stmtPerm) {
        throw new Exception("Error preparando consulta de permisos: " . $conn->error);
    }
    $stmtPerm->bind_param("i", $userId);
    $stmtPerm->execute();
    $stmtPerm->store_result();

    if ($stmtPerm->num_rows === 0) {
        $stmtPerm->close();
        sendJsonResponse(errorResponse('No tienes permiso para desbloquear repuestos', 403), 403);
    }
    $stmtPerm->close();

    // 3. Get Input
    $input = json_decode(file_get_contents('php://input'), true);
    $servicioId = isset($input['servicio_id']) ? intval($input['servicio_id']) : 0;
    $motivo = isset($input['motivo']) ? trim($input['motivo']) : '';

    if ($servicioId <= 0 || empty($motivo)) {
        sendJsonResponse(errorResponse('Faltan datos obligatorios (servicio_id, motivo)', 400), 400);
    }

    // 4. Record Unlock
    $sqlInsert = "INSERT INTO servicios_desbloqueos_repuestos (servicio_id, usuario_id_autoriza, motivo, ip_address) VALUES (?, ?, ?, ?)";
    $stmt = $conn->prepare($sqlInsert);
    if (!$stmt) {
        throw new Exception("Error preparando inserción: " . $conn->error);
    }

    $ip = $_SERVER['REMOTE_ADDR'];
    $stmt->bind_param("iiss", $servicioId, $userId, $motivo, $ip);

    if (!$stmt->execute()) {
        throw new Exception("Error al insertar desbloqueo: " . $stmt->error);
    }

    $stmt->close();

    sendJsonResponse(successResponse(true, 'Repuestos desbloqueados exitosamente'));

} catch (Exception $e) {
    if (!headers_sent()) {
        sendJsonResponse(errorResponse('Error del servidor: ' . $e->getMessage(), 500), 500);
    }
}
?>