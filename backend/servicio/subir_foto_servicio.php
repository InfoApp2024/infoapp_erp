<?php
// header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require '../conexion.php';
require '../auth_middleware.php';
require_once '../workflow/workflow_helper.php';

try {
    $user_data = requireAuth();

    // Verificar que se subió un archivo
    if (!isset($_FILES['imagen']) || $_FILES['imagen']['error'] !== UPLOAD_ERR_OK) {
        throw new Exception('No se recibió la imagen o hubo un error en la subida');
    }

    // Obtener datos del POST
    $servicio_id = $_POST['servicio_id'] ?? null;
    $tipo_foto = $_POST['tipo_foto'] ?? null;
    $descripcion = $_POST['descripcion'] ?? '';

    // Validaciones
    if (!$servicio_id) {
        throw new Exception('servicio_id es requerido');
    }

    if (!in_array($tipo_foto, ['antes', 'despues'])) {
        throw new Exception('tipo_foto debe ser "antes" o "despues"');
    }

    // Validar que el servicio existe
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM servicios WHERE id = ?");
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if ($row['count'] == 0) {
        throw new Exception('Servicio no encontrado');
    }

    // Validar archivo
    $archivo = $_FILES['imagen'];
    $tipos_permitidos = ['image/jpeg', 'image/jpg', 'image/png', 'image/webp'];

    if (!in_array($archivo['type'], $tipos_permitidos)) {
        throw new Exception('Tipo de archivo no permitido. Solo JPEG, PNG y WebP');
    }

    if ($archivo['size'] > 5 * 1024 * 1024) { // 5MB máximo
        throw new Exception('El archivo es demasiado grande. Máximo 5MB');
    }

    // Crear directorio si no existe
    $directorio_base = 'uploads/servicios/fotos/';
    if (!file_exists($directorio_base)) {
        mkdir($directorio_base, 0755, true);
    }

    // Generar nombre único para el archivo
    $extension = pathinfo($archivo['name'], PATHINFO_EXTENSION);
    $timestamp = time();
    $nombre_archivo = "servicio_{$servicio_id}_{$tipo_foto}_{$timestamp}.{$extension}";
    $ruta_completa = $directorio_base . $nombre_archivo;

    // Mover archivo subido
    if (!move_uploaded_file($archivo['tmp_name'], $ruta_completa)) {
        throw new Exception('Error al guardar el archivo');
    }

    // Obtener el siguiente orden de visualización
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

    // Insertar registro en la base de datos
    $stmt = $conn->prepare("
        INSERT INTO fotos_servicio 
        (servicio_id, tipo_foto, nombre_archivo, ruta_archivo, descripcion, orden_visualizacion, tamaño_bytes) 
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ");

    $stmt->bind_param(
        "isssiii",
        $servicio_id,
        $tipo_foto,
        $nombre_archivo,
        $ruta_completa,
        $descripcion,
        $orden,
        $archivo['size']
    );

    if ($stmt->execute()) {
        $foto_id = $conn->insert_id;

        // ✅ NUEVO: Evaluar triggers automáticos (ej: FOTO_SUBIDA)
        $usuario_id = $user_data['id'] ?? null;
        $workflow_res = WorkflowHelper::evaluarTriggersAutomaticos($conn, $servicio_id, $usuario_id);

        echo json_encode([
            'success' => true,
            'message' => 'Foto subida exitosamente',
            'foto_id' => $foto_id,
            'nombre_archivo' => $nombre_archivo,
            'ruta_archivo' => $ruta_completa,
            'tipo_foto' => $tipo_foto,
            'tamaño_bytes' => $archivo['size'],
            'workflow' => $workflow_res // ✅ NUEVO: Informar al frontend
        ]);
    } else {
        // Si falla la BD, eliminar el archivo
        unlink($ruta_completa);
        throw new Exception('Error al guardar en la base de datos');
    }
} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

if (isset($stmt))
    $stmt->close();
if (isset($conn))
    $conn->close();
