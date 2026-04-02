<?php
// crear_funcionario.php - Crear nuevo funcionario para un cliente
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'funcionarios/crear_funcionario.php', 'create_funcionario');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos JSON inválidos');
    }

    // Validar campos obligatorios
    $nombre = isset($input['nombre']) ? trim($input['nombre']) : '';
    if (empty($nombre)) {
        throw new Exception('El nombre del funcionario es obligatorio');
    }

    $cargo = $input['cargo'] ?? null;
    $empresa = $input['empresa'] ?? null;
    $telefono = $input['telefono'] ?? null;
    $correo = $input['correo'] ?? null;
    $cliente_id = isset($input['cliente_id']) ? (int) $input['cliente_id'] : null;

    $sql = "INSERT INTO funcionario (nombre, cargo, empresa, telefono, correo, cliente_id, activo) VALUES (?, ?, ?, ?, ?, ?, 1)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssi", $nombre, $cargo, $empresa, $telefono, $correo, $cliente_id);

    if (!$stmt->execute()) {
        throw new Exception("Error al crear funcionario: " . $stmt->error);
    }

    $funcionario_id = $stmt->insert_id;

    // ✅ FIX: Retornar estructura plana que ServiciosApiService espera
    sendJsonResponse([
        'success' => true,
        'message' => 'Funcionario creado exitosamente',
        'funcionario_id' => $funcionario_id,
        'nombre' => $nombre
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
