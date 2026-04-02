<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/anular_servicio.php', 'cancel_service');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';
    require_once 'helpers/trazabilidad_helper.php';

    if (!isset($conn) || $conn->connect_error) {
        throw new Exception('Error de conexión a la base de datos');
    }

    // PASO 5: Leer y validar input
    $input_raw = file_get_contents('php://input');

    if (empty($input_raw)) {
        throw new Exception('No se recibieron datos');
    }

    $input = json_decode($input_raw, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('JSON inválido: ' . json_last_error_msg());
    }

    // PASO 6: Extraer datos - usuario_id viene del JWT
    $servicio_id = isset($input['servicio_id']) ? (int) $input['servicio_id'] : null;
    $estado_final_id = isset($input['estado_final_id']) ? (int) $input['estado_final_id'] : null;
    $razon = isset($input['razon']) ? trim($input['razon']) : null;

    // NUEVO: Obtener usuario_id del token JWT en lugar del request
    $usuario_id = $currentUser['id'];

    // PASO 7: Validaciones
    if (!$servicio_id) {
        throw new Exception('ID del servicio es requerido');
    }
    if (!$estado_final_id) {
        throw new Exception('Estado final es requerido');
    }
    if (!$razon) {
        throw new Exception('Razón de anulación es requerida');
    }
    if (strlen($razon) < 40) {
        throw new Exception('La razón debe tener al menos 40 caracteres');
    }
    if (strlen($razon) > 500) {
        throw new Exception('La razón no puede exceder 500 caracteres');
    }

    // PASO 8: Verificar servicio existe
    $stmt = $conn->prepare("SELECT estado, anular_servicio, o_servicio FROM servicios WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Error en consulta de verificación');
    }

    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $servicio = $result->fetch_assoc();
    $stmt->close();
    $stmt = null;

    if (!$servicio) {
        throw new Exception('Servicio no encontrado');
    }

    if ($servicio['anular_servicio'] == 1) {
        throw new Exception('El servicio ya está anulado');
    }

    // PASO 8.5: Verificar si tiene repuestos asignados
    // No se puede anular si tiene repuestos, deben eliminarse primero para retornar al inventario.
    $stmtCheckParts = $conn->prepare("SELECT COUNT(*) as total FROM servicio_repuestos WHERE servicio_id = ?");
    $stmtCheckParts->bind_param("i", $servicio_id);
    $stmtCheckParts->execute();
    $resultParts = $stmtCheckParts->get_result();
    $partsCount = (int) $resultParts->fetch_assoc()['total'];
    $stmtCheckParts->close();

    if ($partsCount > 0) {
        throw new Exception("No es posible anular el servicio porque tiene $partsCount repuestos asignados. Debes eliminar los repuestos primero para devolverlos al inventario.");
    }

    // PASO 9: Verificar estado final
    $stmt = $conn->prepare("SELECT nombre_estado FROM estados_proceso WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Error en consulta de estado');
    }

    $stmt->bind_param("i", $estado_final_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $estado_final = $result->fetch_assoc();
    $stmt->close();
    $stmt = null;

    if (!$estado_final) {
        throw new Exception('Estado final no válido');
    }

    // PASO 10: Actualizar servicio
    $stmt = $conn->prepare("
        UPDATE servicios 
        SET estado = ?, 
            anular_servicio = 1, 
            razon = ?,
            fecha_finalizacion = NOW(),
            fecha_actualizacion = NOW(),
            usuario_ultima_actualizacion = ?,
            es_finalizado = 1
        WHERE id = ?
    ");

    if (!$stmt) {
        throw new Exception('Error preparando actualización');
    }

    $stmt->bind_param("isii", $estado_final_id, $razon, $usuario_id, $servicio_id);

    if (!$stmt->execute()) {
        throw new Exception('Error ejecutando actualización');
    }

    $affected_rows = $stmt->affected_rows;
    $stmt->close();
    $stmt = null;

    // ✅ LOG DE TRAZABILIDAD: Registrar cambio de estado por anulación
    TrazabilidadHelper::registrarTransicionEstado($conn, $servicio_id, $estado_final_id, $usuario_id);

    // PASO 11: Respuesta exitosa con contexto de usuario
    sendJsonResponse([
        'success' => true,
        'message' => 'Servicio anulado exitosamente y movido al estado final: ' . $estado_final['nombre_estado'],
        'data' => [
            'servicio_id' => $servicio_id,
            'o_servicio' => (int) $servicio['o_servicio'],
            'estado_final' => $estado_final['nombre_estado'],
            'razon' => $razon,
            'affected_rows' => $affected_rows,
            'anulado_by_user' => $currentUser['usuario'],
            'anulado_by_role' => $currentUser['rol'],
            'usuario_id' => $usuario_id
        ]
    ]);

} catch (Exception $e) {
    // Limpiar recursos en caso de error
    if (isset($stmt) && $stmt !== null) {
        $stmt->close();
        $stmt = null;
    }

    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($stmt) && $stmt !== null) {
    $stmt->close();
}
if (isset($conn) && $conn !== null) {
    $conn->close();
}
?>