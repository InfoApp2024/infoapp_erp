<?php
// backend/operaciones/crear_operacion.php
require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación JWT
    $currentUser = requireAuth();

    // 2. Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // 3. Obtener datos
    $json = file_get_contents('php://input');
    $data = json_decode($json, true);

    if (!isset($data['servicio_id']) || !isset($data['descripcion'])) {
        sendJsonResponse(errorResponse('Datos incompletos (servicio_id, descripcion)'), 400);
    }

    $servicio_id = intval($data['servicio_id']);
    $descripcion = trim($data['descripcion']);
    $actividad_id = isset($data['actividad_estandar_id']) ? intval($data['actividad_estandar_id']) : null;
    $tecnico_id = isset($data['tecnico_responsable_id']) ? intval($data['tecnico_responsable_id']) : null;

    // Forzamos fecha_inicio = NOW() si no viene una específica
    $fecha_inicio = isset($data['fecha_inicio']) ? $data['fecha_inicio'] : date('Y-m-d H:i:s');
    $observaciones = isset($data['observaciones']) ? trim($data['observaciones']) : null;

    // 4. Conexión a BD
    require '../conexion.php';

    // 4.5. Verificar si el servicio está en un estado final protegido
    $stmt_check = $conn->prepare("
        SELECT e.estado_base_codigo 
        FROM servicios s
        INNER JOIN estados_proceso e ON s.estado = e.id
        WHERE s.id = ?
    ");
    $stmt_check->bind_param("i", $servicio_id);
    $stmt_check->execute();
    $res_check = $stmt_check->get_result();
    
    if ($row_check = $res_check->fetch_assoc()) {
        $estado_base = $row_check['estado_base_codigo'];
        if (in_array($estado_base, ['FINALIZADO', 'CERRADO', 'LEGALIZADO', 'CANCELADO'])) {
            sendJsonResponse(errorResponse("No se pueden agregar operaciones a un servicio en estado final ($estado_base)."), 403);
            exit;
        }
    }
    $stmt_check->close();

    // 5. Insertar operación
    $sql = "INSERT INTO operaciones (servicio_id, actividad_estandar_id, descripcion, fecha_inicio, tecnico_responsable_id, observaciones) 
            VALUES (?, ?, ?, ?, ?, ?)";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iissis", $servicio_id, $actividad_id, $descripcion, $fecha_inicio, $tecnico_id, $observaciones);

    if ($stmt->execute()) {
        $id = $conn->insert_id;
        sendJsonResponse(successResponse(['id' => $id], 'Operación creada exitosamente'));
    } else {
        sendJsonResponse(errorResponse('Error al crear operación: ' . $conn->error), 500);
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}
?>