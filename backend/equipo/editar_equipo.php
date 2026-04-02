<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/editar_equipo.php', 'update_equipment');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';

    // PASO 5: Leer datos del request
    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input) {
        throw new Exception('Datos JSON no válidos');
    }

    // PASO 6: Validar campos obligatorios
    if (
        empty($input['id']) ||
        empty($input['nombre']) ||
        empty($input['placa']) ||
        empty($input['nombre_empresa'])
    ) {
        throw new Exception('Los campos ID, nombre, placa y empresa son obligatorios');
    }

    $id = (int) $input['id'];
    $cliente_id = isset($input['cliente_id']) ? intval($input['cliente_id']) : null;
    $estado_id = isset($input['estado_id']) ? intval($input['estado_id']) : null;

    // PASO 7: Verificar existencia del equipo
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM equipos WHERE id = ? AND activo = 1");
    $stmt->bind_param("i", $id);
    $stmt->execute();
    $result = $stmt->get_result();
    $exists = $result->fetch_assoc()['count'] ?? 0;

    if ($exists == 0) {
        throw new Exception('El equipo no existe o no está activo');
    }

    // PASO 8: Validar placa duplicada
    // PASO 8: Validar placa duplicada (scope empresa)
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM equipos WHERE placa = ? AND nombre_empresa = ? AND id != ? AND activo = 1");
    $stmt->bind_param("ssi", $input['placa'], $input['nombre_empresa'], $id);
    $stmt->execute();
    $duplicadoPlaca = $stmt->get_result()->fetch_assoc()['count'] ?? 0;
    $stmt->close();

    if ($duplicadoPlaca > 0) {
        sendJsonResponse(['success' => false, 'message' => 'Ya existe otro equipo con esta placa para esta empresa', 'error_code' => 'DUPLICATE_PLACA'], 409);
    }

    // PASO 8.5: Validar código duplicado (scope empresa)
    if (!empty($input['codigo'])) {
        $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM equipos WHERE codigo = ? AND nombre_empresa = ? AND id != ? AND activo = 1");
        $stmt->bind_param("ssi", $input['codigo'], $input['nombre_empresa'], $id);
        $stmt->execute();
        $duplicadoCodigo = $stmt->get_result()->fetch_assoc()['count'] ?? 0;
        $stmt->close();

        if ($duplicadoCodigo > 0) {
            sendJsonResponse(['success' => false, 'message' => 'Ya existe otro equipo con este código para esta empresa', 'error_code' => 'DUPLICATE_CODIGO'], 409);
        }
    }

    // PASO 9: Validar estado_id si fue enviado
    if (!empty($estado_id)) {
        $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM estados_proceso WHERE id = ?");
        $stmt->bind_param("i", $estado_id);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($res['count'] == 0) {
            throw new Exception("El estado_id ($estado_id) no existe en la tabla estados_proceso");
        }
    }

    // PASO 10: Asignar usuario que actualiza
    $usuario_registro = $currentUser['usuario'] ?? 'sistema';

    // PASO 11: Actualizar equipo (incluyendo estado_id)
    $stmt = $conn->prepare("
        UPDATE equipos SET 
            nombre = ?, 
            modelo = ?, 
            marca = ?, 
            placa = ?, 
            codigo = ?, 
            ciudad = ?, 
            planta = ?, 
            linea_prod = ?, 
            nombre_empresa = ?, 
            usuario_registro = ?, 
            cliente_id = ?,
            estado_id = ?
        WHERE id = ? AND activo = 1
    ");

    $stmt->bind_param(
        "ssssssssssiii",
        $input['nombre'],
        $input['modelo'],
        $input['marca'],
        $input['placa'],
        $input['codigo'],
        $input['ciudad'],
        $input['planta'],
        $input['linea_prod'],
        $input['nombre_empresa'],
        $usuario_registro,
        $cliente_id,
        $estado_id,
        $id
    );

    if (!$stmt->execute()) {
        throw new Exception('Error al actualizar el equipo: ' . $stmt->error);
    }

    // PASO 12: Respuesta exitosa
    sendJsonResponse([
        'success' => true,
        'message' => 'Equipo actualizado exitosamente',
        'updated_by' => $usuario_registro,
        'data' => [
            'id' => $id,
            'nombre' => $input['nombre'],
            'placa' => $input['placa'],
            'empresa' => $input['nombre_empresa'],
            'cliente_id' => $cliente_id,
            'estado_id' => $estado_id
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>