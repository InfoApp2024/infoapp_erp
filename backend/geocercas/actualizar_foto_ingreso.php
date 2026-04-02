<?php
// backend/geocercas/actualizar_foto_ingreso.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

// Log de depuración
$logFile = '../logs/geocercas_debug.log';
function logDebug($message)
{
    global $logFile;
    $logDir = dirname($logFile);
    if (!is_dir($logDir)) {
        @mkdir($logDir, 0777, true);
    }
    $timestamp = date('Y-m-d H:i:s');
    @file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
}

logDebug("=== ACTUALIZAR FOTO INGRESO ===");
logDebug("POST: " . json_encode($_POST));

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logDebug("Usuario autenticado: " . $currentUser['id']);

    require '../conexion.php';

    $registro_id = isset($_POST['registro_id']) ? intval($_POST['registro_id']) : null;
    $fecha_captura = isset($_POST['fecha_captura']) ? $_POST['fecha_captura'] : null;

    logDebug("registro_id: $registro_id");
    logDebug("fecha_captura: $fecha_captura");

    if (!$registro_id) {
        throw new Exception("ID de registro requerido");
    }

    $usuario_id = $currentUser['id'];

    // Verificar que el registro pertenece al usuario
    $sqlCheck = "SELECT id FROM registros_geocerca WHERE id = ? AND usuario_id = ?";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("ii", $registro_id, $usuario_id);
    $stmtCheck->execute();
    $resultCheck = $stmtCheck->get_result();

    if ($resultCheck->num_rows === 0) {
        throw new Exception("Registro no encontrado o no pertenece al usuario");
    }

    // Procesar Evidencia (Foto)
    $foto_ruta = null;
    if (isset($_FILES['evidencia'])) {
        logDebug("Archivo evidencia recibido");
        logDebug("Error code: " . $_FILES['evidencia']['error']);

        if ($_FILES['evidencia']['error'] !== UPLOAD_ERR_OK) {
            $errorMessages = [
                UPLOAD_ERR_INI_SIZE => 'El archivo excede upload_max_filesize',
                UPLOAD_ERR_FORM_SIZE => 'El archivo excede MAX_FILE_SIZE',
                UPLOAD_ERR_PARTIAL => 'El archivo se subió parcialmente',
                UPLOAD_ERR_NO_FILE => 'No se subió ningún archivo',
                UPLOAD_ERR_NO_TMP_DIR => 'Falta carpeta temporal',
                UPLOAD_ERR_CANT_WRITE => 'Error al escribir en disco',
                UPLOAD_ERR_EXTENSION => 'Extensión PHP detuvo la subida'
            ];
            $errorMsg = $errorMessages[$_FILES['evidencia']['error']] ?? 'Error desconocido';
            throw new Exception("Error en upload: $errorMsg (código: {$_FILES['evidencia']['error']})");
        }

        $uploadDir = '../uploads/geocercas/';
        logDebug("Upload dir: $uploadDir");

        if (!is_dir($uploadDir)) {
            logDebug("Creando directorio de uploads...");
            if (!mkdir($uploadDir, 0777, true)) {
                throw new Exception("No se pudo crear el directorio de uploads");
            }
        }

        if (!is_writable($uploadDir)) {
            throw new Exception("El directorio de uploads no tiene permisos de escritura");
        }

        $extension = pathinfo($_FILES['evidencia']['name'], PATHINFO_EXTENSION);
        if (empty($extension))
            $extension = 'jpg';

        $filename = 'ingreso_' . $usuario_id . '_' . time() . '.' . $extension;
        $targetFile = $uploadDir . $filename;

        logDebug("Target file: $targetFile");

        if (move_uploaded_file($_FILES['evidencia']['tmp_name'], $targetFile)) {
            $foto_ruta = 'uploads/geocercas/' . $filename;
            logDebug("Archivo movido exitosamente: $foto_ruta");
        } else {
            throw new Exception("Error al mover el archivo de evidencia. Verifique permisos.");
        }
    } else {
        throw new Exception("No se recibió archivo de evidencia");
    }

    // Normalizar fecha de captura
    date_default_timezone_set('America/Bogota');
    if ($fecha_captura) {
        $fecha_captura = date('Y-m-d H:i:s', strtotime($fecha_captura));
    } else {
        $fecha_captura = date('Y-m-d H:i:s');
    }

    // Actualizar solo la foto y fecha de captura
    $sql = "UPDATE registros_geocerca 
            SET foto_ingreso = ?, fecha_captura_ingreso = ? 
            WHERE id = ? AND usuario_id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("ssii", $foto_ruta, $fecha_captura, $registro_id, $usuario_id);

    logDebug("Ejecutando UPDATE...");
    if ($stmt->execute()) {
        logDebug("✅ Foto de ingreso actualizada exitosamente");
        sendJsonResponse([
            'success' => true,
            'message' => 'Foto de ingreso actualizada',
            'registro_id' => $registro_id
        ]);
    } else {
        throw new Exception("Error al actualizar foto: " . $stmt->error);
    }
} catch (Exception $e) {
    logDebug("❌ ERROR: " . $e->getMessage());
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
