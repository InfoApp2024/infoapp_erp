<?php
require_once __DIR__ . '/../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require __DIR__ . '/../../conexion.php';

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Método no permitido');
    }

    $input = json_decode(file_get_contents('php://input'), true);
    $tipoAnterior = isset($input['tipo_anterior']) ? trim($input['tipo_anterior']) : null;
    $tipoNuevo = isset($input['tipo_nuevo']) ? trim($input['tipo_nuevo']) : null;

    if (!$tipoAnterior || !$tipoNuevo) {
        throw new Exception('Faltan parámetros');
    }

    $conn->begin_transaction();

    // 1. Actualizar en tabla maestra
    $stmt = $conn->prepare("UPDATE tipos_mantenimiento SET nombre = ? WHERE nombre = ?");
    $stmt->bind_param("ss", $tipoNuevo, $tipoAnterior);
    $stmt->execute();

    // 2. Actualizar en servicios (histórico)
    $stmt2 = $conn->prepare("UPDATE servicios SET tipo_mantenimiento = ? WHERE tipo_mantenimiento = ?");
    $stmt2->bind_param("ss", $tipoNuevo, $tipoAnterior);
    $stmt2->execute();

    $conn->commit();

    sendJsonResponse(['success' => true, 'message' => 'Actualizado exitosamente']);

} catch (Exception $e) {
    if (isset($conn)) $conn->rollback();
    sendJsonResponse(['success' => false,'message' => $e->getMessage()], 500);
} finally {
    if (isset($conn)) $conn->close();
}
?>
