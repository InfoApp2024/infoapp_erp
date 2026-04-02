<?php
// backend/geocercas/registrar_ingreso.php
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

logDebug("=== INICIO REGISTRO INGRESO ===");
logDebug("POST: " . json_encode($_POST));
logDebug("FILES: " . json_encode(array_map(function ($file) {
    return [
        'name' => $file['name'],
        'size' => $file['size'],
        'error' => $file['error'],
        'tmp_name' => $file['tmp_name']
    ];
}, $_FILES)));

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logDebug("Usuario autenticado: " . $currentUser['id']);

    require '../conexion.php';

    // Leer datos del request
    // Si viene con archivo (multipart), los datos están en $_POST
    // Si viene sin archivo (JSON), los datos están en el body
    $geocerca_id = null;
    $detection_time = null; // ⏱️ Tiempo GPS
    $capture_time = null;   // 📸 Tiempo captura foto

    if (!empty($_POST['geocerca_id'])) {
        // Caso 1: MultipartRequest con archivo (datos en $_POST)
        $geocerca_id = intval($_POST['geocerca_id']);
        $detection_time = isset($_POST['detection_time']) ? $_POST['detection_time'] : null;
        $capture_time = isset($_POST['capture_time']) ? $_POST['capture_time'] : (isset($_POST['fecha_captura']) ? $_POST['fecha_captura'] : null);
        logDebug("Datos recibidos vía POST (multipart)");
    } else {
        // Caso 2: Request JSON sin archivo (datos en body)
        $inputJSON = file_get_contents('php://input');
        logDebug("Raw input: $inputJSON");

        if (!empty($inputJSON)) {
            $input = json_decode($inputJSON, true);
            $geocerca_id = isset($input['geocerca_id']) ? intval($input['geocerca_id']) : null;
            $detection_time = isset($input['detection_time']) ? $input['detection_time'] : null;
            $capture_time = isset($input['capture_time']) ? $input['capture_time'] : (isset($input['fecha_captura']) ? $input['fecha_captura'] : null);
            logDebug("Datos recibidos vía JSON body");
        }
    }

    logDebug("geocerca_id: $geocerca_id");
    logDebug("detection_time: $detection_time");
    logDebug("capture_time: $capture_time");

    if (!$geocerca_id) {
        throw new Exception("ID de geocerca requerido");
    }

    $usuario_id = $currentUser['id'];

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
        logDebug("⚠️ No se recibió archivo de evidencia");
    }

    // Configurar zona horaria (Colombia)
    date_default_timezone_set('America/Bogota');
    $fecha_servidor = date('Y-m-d H:i:s');

    // ⏱️ Normalizar tiempo de detección (GPS)
    if ($detection_time) {
        $fecha_ingreso = date('Y-m-d H:i:s', strtotime($detection_time));
    } else {
        $fecha_ingreso = $fecha_servidor;
    }

    // 📸 Normalizar tiempo de captura (Foto)
    if ($capture_time) {
        $fecha_captura_ingreso = date('Y-m-d H:i:s', strtotime($capture_time));
    } else {
        $fecha_captura_ingreso = $fecha_servidor;
    }

    logDebug("Fecha Ingreso (GPS): $fecha_ingreso");
    logDebug("Fecha Captura (Foto): $fecha_captura_ingreso");

    // 🧪 Validación de cordura (Sanity Check)
    $observaciones_lista = [];
    if ($detection_time) {
        $server_ts = strtotime($fecha_servidor);
        $detection_ts = strtotime($fecha_ingreso);
        $diff_seconds = $server_ts - $detection_ts;

        if ($detection_ts > ($server_ts + 60)) { // Margen de 1 minuto
            $observaciones_lista[] = "[SISTEMA]⚠️ FECHA FUTURA: El dispositivo reportó una hora posterior a la del servidor. (GPS: $fecha_ingreso vs Server: $fecha_servidor)";
        } elseif ($diff_seconds > 86400) { // Más de 24 horas
            $horas_atraso = round($diff_seconds / 3600, 1);
            $observaciones_lista[] = "[SISTEMA]⚠️ RETRASO CRÍTICO: El reporte tiene $horas_atraso horas de antigüedad. Posible sincronización tardía o error de reloj.";
        }
    }
    $observaciones = !empty($observaciones_lista) ? implode("\n", $observaciones_lista) : null;

    // 1. Verificar si ya tiene un ingreso activo en esta geocerca
    $sqlCheck = "SELECT id FROM registros_geocerca 
                 WHERE geocerca_id = ? AND usuario_id = ? AND fecha_salida IS NULL 
                 LIMIT 1";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("ii", $geocerca_id, $usuario_id);
    $stmtCheck->execute();
    $resultCheck = $stmtCheck->get_result();

    if ($resultCheck->num_rows > 0) {
        $row = $resultCheck->fetch_assoc();
        logDebug("Usuario ya tiene ingreso activo: " . $row['id']);
        sendJsonResponse([
            'success' => true,
            'message' => 'El usuario ya tiene un ingreso activo',
            'registro_id' => $row['id']
        ]);
    }

    // 2. Registrar nuevo ingreso con evidencia (y observaciones si falló validación)
    $sql = "INSERT INTO registros_geocerca (geocerca_id, usuario_id, fecha_ingreso, foto_ingreso, fecha_captura_ingreso, observaciones) 
            VALUES (?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("iissss", $geocerca_id, $usuario_id, $fecha_ingreso, $foto_ruta, $fecha_captura_ingreso, $observaciones);

    logDebug("Ejecutando INSERT...");
    if ($stmt->execute()) {
        $registro_id = $stmt->insert_id;
        logDebug("✅ Ingreso registrado exitosamente. ID: $registro_id");
        sendJsonResponse([
            'success' => true,
            'message' => 'Ingreso registrado con evidencia',
            'registro_id' => $registro_id
        ]);
    } else {
        throw new Exception("Error al registrar ingreso: " . $stmt->error);
    }
} catch (Exception $e) {
    logDebug("❌ ERROR: " . $e->getMessage());
    logDebug("Stack trace: " . $e->getTraceAsString());
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
