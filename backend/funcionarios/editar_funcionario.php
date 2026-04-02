<?php
// editar_funcionario.php - Actualizar funcionario existente
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, 'funcionarios/editar_funcionario.php', 'update_funcionario');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos JSON inválidos');
    }

    $funcionario_id = isset($input['funcionario_id']) ? (int) $input['funcionario_id'] : null;
    if (!$funcionario_id) {
        throw new Exception('ID de funcionario requerido');
    }

    $nombre = isset($input['nombre']) ? trim($input['nombre']) : '';
    if (empty($nombre)) {
        throw new Exception('El nombre del funcionario es obligatorio');
    }

    $cargo = $input['cargo'] ?? null;
    $empresa = $input['empresa'] ?? null;
    $telefono = $input['telefono'] ?? null;
    $correo = $input['correo'] ?? null;
    $cliente_id = isset($input['cliente_id']) ? (int) $input['cliente_id'] : null;

    $sql = "UPDATE funcionario SET nombre = ?, cargo = ?, empresa = ?, telefono = ?, correo = ?, cliente_id = ? WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("sssssii", $nombre, $cargo, $empresa, $telefono, $correo, $cliente_id, $funcionario_id);

    if (!$stmt->execute()) {
        throw new Exception("Error al actualizar funcionario: " . $stmt->error);
    }

    // ✅ FIX: Retornar estructura plana para consistencia
    sendJsonResponse([
        'success' => true,
        'message' => 'Funcionario actualizado exitosamente'
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
