<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/subir_foto_servicio_base64.php', 'upload_photo');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';
    require_once '../workflow/workflow_helper.php';

    // PASO 5: Leer y validar input
    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON');
    }

    // PASO 6: Obtener datos
    $servicio_id = $input['servicio_id'] ?? null;
    $tipo_foto = $input['tipo_foto'] ?? null;
    $descripcion = $input['descripcion'] ?? '';
    $imagen_base64 = $input['imagen_base64'] ?? null;
    $nombre_archivo = $input['nombre_archivo'] ?? null;
    $orden_visualizacion_input = $input['orden_visualizacion'] ?? null;

    // PASO 7: Validaciones
    if (!$servicio_id) {
        throw new Exception('servicio_id es requerido');
    }

    if (!in_array($tipo_foto, ['antes', 'despues'])) {
        throw new Exception('tipo_foto debe ser "antes" o "despues"');
    }

    if (!$imagen_base64) {
        throw new Exception('imagen_base64 es requerida');
    }

    if (!$nombre_archivo) {
        throw new Exception('nombre_archivo es requerido');
    }

    // PASO 8: Validar que el servicio existe
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE id = ?");
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if ($row['count'] == 0) {
        throw new Exception('Servicio no encontrado');
    }

    // PASO 8.5: Verificar si el servicio esté en un estado final protegido
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
            throw new Exception("No se pueden subir fotos a un servicio en estado final ($estado_base).");
        }
    }
    $stmt_check->close();

    // PASO 9: Decodificar Base64
    $imagen_data = base64_decode($imagen_base64);

    if ($imagen_data === false) {
        throw new Exception('Error decodificando imagen Base64');
    }

    // PASO 10: Validar tamaño (5MB máximo)
    if (strlen($imagen_data) > 5 * 1024 * 1024) {
        throw new Exception('El archivo es demasiado grande. Máximo 5MB');
    }

    // PASO 11: Crear directorio si no existe
    $directorio_base = '../uploads/servicios/fotos/';
    if (!file_exists($directorio_base)) {
        mkdir($directorio_base, 0755, true);
    }

    $ruta_completa = $directorio_base . $nombre_archivo;

    // PASO 12: Guardar archivo
    if (file_put_contents($ruta_completa, $imagen_data) === false) {
        throw new Exception('Error al guardar el archivo');
    }

    // PASO 13: Obtener el siguiente orden de visualización
    if ($orden_visualizacion_input !== null) {
        $orden = intval($orden_visualizacion_input);
    } else {
        $stmt = $conn->prepare("
            SELECT COALESCE(MAX(orden_visualizacion), 0) + 1 as siguiente_orden 
            FROM fotos_servicio 
            WHERE servicio_id = ? AND tipo_foto = ?
        ");
        $stmt->bind_param("is", $servicio_id, $tipo_foto);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $orden = $row['siguiente_orden'];
    }

    // PASO 14: Insertar registro en la base de datos
    $stmt = $conn->prepare("
        INSERT INTO fotos_servicio 
        (servicio_id, tipo_foto, nombre_archivo, ruta_archivo, descripcion, orden_visualizacion, tamaño_bytes) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");

    $tamaño_bytes = strlen($imagen_data);

    $stmt->bind_param(
        "isssiii",
        $servicio_id,
        $tipo_foto,
        $nombre_archivo,
        $ruta_completa,
        $descripcion,
        $orden,
        $tamaño_bytes
    );

    if ($stmt->execute()) {
        $foto_id = $conn->insert_id;

        // ✅ NUEVO: Evaluar triggers automáticos (ej: FOTO_SUBIDA)
        $usuario_id = $currentUser['id'];
        $workflow_res = WorkflowHelper::evaluarTriggersAutomaticos($conn, $servicio_id, $usuario_id);

        // PASO 15: Respuesta exitosa con contexto de usuario
        sendJsonResponse([
            'success' => true,
            'message' => 'Foto subida exitosamente',
            'data' => [
                'foto_id' => $foto_id,
                'nombre_archivo' => $nombre_archivo,
                'ruta_archivo' => $ruta_completa,
                'tipo_foto' => $tipo_foto,
                'tamaño_bytes' => $tamaño_bytes,
                'uploaded_by_user' => $currentUser['usuario'],
                'uploaded_by_role' => $currentUser['rol'],
                'servicio_id' => $servicio_id,
                'workflow' => $workflow_res // ✅ NUEVO: Informar al frontend
            ]
        ], 201);
    } else {
        // Si falla la BD, eliminar el archivo
        unlink($ruta_completa);
        throw new Exception('Error al guardar en la base de datos');
    }
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

// Cerrar conexiones
if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
