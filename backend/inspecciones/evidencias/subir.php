<?php
// evidencias/subir.php - Subir evidencia fotográfica - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/evidencias/subir.php', 'upload_evidence');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON');
    }

    $inspeccion_id = $input['inspeccion_id'] ?? null;
    $actividad_id = $input['actividad_id'] ?? null; // Opcional
    $comentario = $input['comentario'] ?? '';
    $imagen_base64 = $input['imagen_base64'] ?? null;
    $nombre_archivo = $input['nombre_archivo'] ?? null;
    $orden = $input['orden'] ?? null;
    $usuario_id = $currentUser['id'];

    // Validaciones
    if (!$inspeccion_id) {
        throw new Exception('inspeccion_id es requerido');
    }

    if (!$imagen_base64) {
        throw new Exception('imagen_base64 es requerida');
    }

    if (!$nombre_archivo) {
        throw new Exception('nombre_archivo es requerido');
    }

    // Validar que la inspección existe
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM inspecciones WHERE id = ? AND deleted_at IS NULL");
    $stmt->bind_param("i", $inspeccion_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if ($row['count'] == 0) {
        throw new Exception('Inspección no encontrada');
    }
    $stmt->close();

    // Decodificar Base64
    $imagen_data = base64_decode($imagen_base64);

    if ($imagen_data === false) {
        throw new Exception('Error decodificando imagen Base64');
    }

    // Validar tamaño (5MB máximo)
    if (strlen($imagen_data) > 5 * 1024 * 1024) {
        throw new Exception('El archivo es demasiado grande. Máximo 5MB');
    }

    // Crear directorio si no existe
    $directorio_base = '../uploads/inspecciones/evidencias/';
    if (!file_exists($directorio_base)) {
        mkdir($directorio_base, 0755, true);
    }

    $ruta_completa = $directorio_base . $nombre_archivo;

    // Guardar archivo
    if (file_put_contents($ruta_completa, $imagen_data) === false) {
        throw new Exception('Error al guardar el archivo');
    }

    // Obtener el siguiente orden si no se proporcionó
    if ($orden === null) {
        $stmt = $conn->prepare("
            SELECT COALESCE(MAX(orden), 0) + 1 as siguiente_orden 
            FROM inspecciones_evidencias 
            WHERE inspeccion_id = ?
        ");
        $stmt->bind_param("i", $inspeccion_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $row = $result->fetch_assoc();
        $orden = $row['siguiente_orden'];
        $stmt->close();
    }

    // Insertar registro en la base de datos
    $stmt = $conn->prepare("
        INSERT INTO inspecciones_evidencias 
        (inspeccion_id, actividad_id, ruta_imagen, comentario, orden, created_by) 
        VALUES (?, ?, ?, ?, ?, ?)
    ");

    $actividad_id_param = $actividad_id ? $actividad_id : null;

    $stmt->bind_param(
        "iissii",
        $inspeccion_id,
        $actividad_id_param,
        $ruta_completa,
        $comentario,
        $orden,
        $usuario_id
    );

    if ($stmt->execute()) {
        $evidencia_id = $conn->insert_id;

        sendJsonResponse([
            'success' => true,
            'message' => 'Evidencia subida exitosamente',
            'data' => [
                'id' => $evidencia_id,
                'inspeccion_id' => $inspeccion_id,
                'actividad_id' => $actividad_id,
                'ruta_imagen' => $ruta_completa,
                'comentario' => $comentario,
                'orden' => $orden,
                'tamaño_bytes' => strlen($imagen_data),
                'uploaded_by_user' => $currentUser['usuario']
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

if (isset($stmt)) {
    $stmt->close();
}
if (isset($conn)) {
    $conn->close();
}
?>