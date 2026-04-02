<?php
// eliminar.php - Eliminar cliente (Soft Delete o Físico si no tiene historial)
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth(); // Podríamos requerir admin: requireAdmin()
    logAccess($currentUser, 'clientes/eliminar.php', 'delete_client');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input || !isset($input['id'])) {
        throw new Exception('ID de cliente requerido');
    }

    $id = (int)$input['id'];

    // Verificar si el cliente tiene registros relacionados (ej: facturas, órdenes, equipos)
    // El usuario mencionó: "1 = Activo, 0 = Inactivo (No borres clientes con historial)."
    // Aquí asumimos que si queremos "eliminar", primero intentamos soft delete (estado = 0)
    
    // Cambiar estado a inactivo (0) en lugar de borrar físicamente
    // Si se desea borrado físico, se debería verificar primero si hay dependencias.
    // Por seguridad, haremos soft delete.

    $sql = "UPDATE clientes SET estado = 0 WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        sendJsonResponse(successResponse(null, 'Cliente desactivado correctamente'));
    } else {
        throw new Exception("Error al desactivar cliente");
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
