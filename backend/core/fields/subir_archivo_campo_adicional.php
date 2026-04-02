<?php
// Subir archivos/imágenes para campos adicionales - VERSIÓN CORREGIDA
require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'Unauthorized']);
    exit;
}

require '../../conexion.php';

// Función de logging mejorada
function logMessage($message)
{
    $logFile = "subir_archivos_" . date('Y-m-d') . ".log";
    $timestamp = date('Y-m-d H:i:s');
    error_log("[$timestamp] $message\n", 3, $logFile);

    // También imprimir para debug inmediato
    error_log("UPLOAD_DEBUG: $message");
}

try {
    logMessage("=== INICIO SUBIR ARCHIVO CAMPO ADICIONAL ===");
    logMessage("REQUEST_METHOD: " . $_SERVER['REQUEST_METHOD']);
    logMessage("DOCUMENT_ROOT: " . $_SERVER['DOCUMENT_ROOT']);
    logMessage("SCRIPT_FILENAME: " . $_SERVER['SCRIPT_FILENAME']);
    logMessage("__DIR__: " . __DIR__);

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('Solo se permite método POST');
    }

    // Obtener datos JSON
    $input = file_get_contents('php://input');
    logMessage("Input length: " . strlen($input));

    $data = json_decode($input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error en JSON: ' . json_last_error_msg());
    }

    // Validar datos requeridos
    if (!isset($data['servicio_id']) || !isset($data['campo_id']) || !isset($data['tipo_campo']) || !isset($data['archivo_base64']) || !isset($data['nombre_archivo'])) {
        throw new Exception('Faltan datos requeridos: servicio_id, campo_id, tipo_campo, archivo_base64, nombre_archivo');
    }

    $servicio_id = intval($data['servicio_id']);
    $campo_id = intval($data['campo_id']);
    $tipo_campo = trim($data['tipo_campo']);
    $archivo_base64 = $data['archivo_base64'];
    $nombre_original = $data['nombre_archivo'];

    logMessage("Servicio ID: $servicio_id, Campo ID: $campo_id, Tipo: $tipo_campo, Archivo: $nombre_original");

    // Validar tipo de campo
    if (!in_array(strtolower($tipo_campo), ['imagen', 'archivo'])) {
        throw new Exception('Tipo de campo no válido. Solo se permiten: imagen, archivo');
    }

    // ✅ DETERMINAR CARPETA DE DESTINO - MÉTODO ABSOLUTO PARA NUBE
    $script_dir = dirname(__FILE__); // Directorio donde está este PHP
    logMessage("Script directory: $script_dir");

    // ✅ NUEVO: Verificar si estamos en entorno de producción (nube)
    $carpeta_base = $script_dir . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'campos_adicionales' . DIRECTORY_SEPARATOR;

    // ✅ NUEVO: Crear ruta absoluta si es necesario
    if (!is_dir($script_dir . DIRECTORY_SEPARATOR . 'uploads')) {
        // Intentar crear desde el directorio del script
        $carpeta_base = $script_dir . DIRECTORY_SEPARATOR . 'uploads' . DIRECTORY_SEPARATOR . 'campos_adicionales' . DIRECTORY_SEPARATOR;
    } else {
        logMessage("Directorio uploads ya existe en: " . $script_dir . DIRECTORY_SEPARATOR . 'uploads');
    }

    if (strtolower($tipo_campo) === 'imagen') {
        $carpeta_destino = $carpeta_base . 'imagenes' . DIRECTORY_SEPARATOR;
    } else {
        $carpeta_destino = $carpeta_base . 'archivos' . DIRECTORY_SEPARATOR;
    }

    logMessage("Carpeta base: $carpeta_base");
    logMessage("Carpeta destino: $carpeta_destino");

    // ✅ CREAR CARPETAS SI NO EXISTEN CON VERIFICACIÓN
    if (!is_dir($carpeta_base)) {
        if (!mkdir($carpeta_base, 0755, true)) {
            throw new Exception("No se pudo crear la carpeta base: $carpeta_base");
        }
        logMessage("Carpeta base creada: $carpeta_base");
    } else {
        logMessage("Carpeta base ya existe: $carpeta_base");
    }

    if (!is_dir($carpeta_destino)) {
        if (!mkdir($carpeta_destino, 0755, true)) {
            throw new Exception("No se pudo crear la carpeta destino: $carpeta_destino");
        }
        logMessage("Carpeta destino creada: $carpeta_destino");
    } else {
        logMessage("Carpeta destino ya existe: $carpeta_destino");
    }

    // ✅ VERIFICAR PERMISOS DE ESCRITURA
    if (!is_writable($carpeta_destino)) {
        throw new Exception("La carpeta destino no es escribible: $carpeta_destino. Permisos: " . substr(sprintf('%o', fileperms($carpeta_destino)), -4));
    }
    logMessage("Carpeta destino es escribible: $carpeta_destino");

    // Generar nombre único para el archivo
    $extension = pathinfo($nombre_original, PATHINFO_EXTENSION);
    $timestamp = time();
    $nombre_unico = "servicio_{$servicio_id}_campo_{$campo_id}_{$timestamp}." . $extension;
    $ruta_completa = $carpeta_destino . $nombre_unico;

    logMessage("Nombre único generado: $nombre_unico");
    logMessage("Ruta completa donde se guardará: $ruta_completa");

    // ✅ DECODIFICAR Y GUARDAR ARCHIVO CON VERIFICACIÓN
    $archivo_decoded = base64_decode($archivo_base64);
    if ($archivo_decoded === false) {
        throw new Exception('Error decodificando archivo base64');
    }

    logMessage("Archivo decodificado exitosamente. Tamaño: " . strlen($archivo_decoded) . " bytes");

    // ✅ ESCRIBIR ARCHIVO CON VERIFICACIÓN COMPLETA
    $bytes_escritos = file_put_contents($ruta_completa, $archivo_decoded);
    if ($bytes_escritos === false) {
        throw new Exception('Error escribiendo archivo al disco en: ' . $ruta_completa);
    }

    logMessage("Archivo escrito exitosamente. Bytes escritos: $bytes_escritos");

    // ✅ VERIFICAR QUE EL ARCHIVO REALMENTE EXISTE
    if (!file_exists($ruta_completa)) {
        throw new Exception("El archivo no se creó correctamente: $ruta_completa");
    }

    $tamaño_verificado = filesize($ruta_completa);
    logMessage("Archivo verificado. Existe: SÍ, Tamaño: $tamaño_verificado bytes");

    // ✅ CONEXIÓN CON MANEJO DE ERRORES MEJORADO
    try {
        $pdo = new PDO("mysql:host=localhost;dbname=u342171239_InfoApp_Test;charset=utf8mb4", "u342171239_Test", "Test_2025/-*");
        $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        logMessage("Conexión a BD establecida exitosamente");
    } catch (PDOException $e) {
        logMessage("ERROR DE CONEXIÓN BD: " . $e->getMessage());
        throw new Exception("Error conectando a base de datos: " . $e->getMessage());
    }
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    logMessage("Conexión a BD establecida");

    // PASO 1: Asegurar que existe el valor en valores_campos_adicionales
    $stmt = $pdo->prepare("SELECT id FROM valores_campos_adicionales WHERE servicio_id = ? AND campo_id = ?");
    $stmt->execute([$servicio_id, $campo_id]);
    $valor_existente = $stmt->fetch();

    $valor_campo_id = null;

    if ($valor_existente) {
        $valor_campo_id = $valor_existente['id'];
        logMessage("Valor existente encontrado con ID: $valor_campo_id");

        $stmt = $pdo->prepare("UPDATE valores_campos_adicionales SET valor_archivo = ?, tipo_campo = ?, fecha_actualizacion = NOW() WHERE id = ?");
        $stmt->execute([$nombre_unico, $tipo_campo, $valor_campo_id]);
    } else {
        $stmt = $pdo->prepare("INSERT INTO valores_campos_adicionales (servicio_id, campo_id, valor_archivo, tipo_campo, fecha_creacion, fecha_actualizacion) VALUES (?, ?, ?, ?, NOW(), NOW())");
        $stmt->execute([$servicio_id, $campo_id, $nombre_unico, $tipo_campo]);

        $valor_campo_id = $pdo->lastInsertId();
        logMessage("Nuevo valor creado con ID: $valor_campo_id");
    }

    // PASO 2: Manejar archivos_campos_adicionales
    $stmt = $pdo->prepare("SELECT id, ruta_archivo FROM archivos_campos_adicionales WHERE valor_campo_id = ?");
    $stmt->execute([$valor_campo_id]);
    $archivo_existente = $stmt->fetch();

    // Calcular dimensiones si es imagen
    $ancho = null;
    $alto = null;
    if (strtolower($tipo_campo) === 'imagen') {
        $image_info = @getimagesize($ruta_completa);
        if ($image_info) {
            $ancho = $image_info[0];
            $alto = $image_info[1];
            logMessage("Dimensiones imagen: {$ancho}x{$alto}");
        }
    }

    // Ruta relativa para la BD
    $ruta_relativa = "uploads/campos_adicionales/" . (strtolower($tipo_campo) === 'imagen' ? 'imagenes/' : 'archivos/') . $nombre_unico;

    if ($archivo_existente) {
        // Eliminar archivo anterior si existe
        $ruta_anterior = $script_dir . DIRECTORY_SEPARATOR . str_replace('/', DIRECTORY_SEPARATOR, $archivo_existente['ruta_archivo']);
        if (file_exists($ruta_anterior)) {
            unlink($ruta_anterior);
            logMessage("Archivo anterior eliminado: $ruta_anterior");
        }

        // Actualizar registro existente
        $stmt = $pdo->prepare("
            UPDATE archivos_campos_adicionales 
            SET nombre_original = ?, nombre_almacenado = ?, ruta_archivo = ?, 
                extension = ?, tamaño_bytes = ?, tipo_mime = ?, 
                ancho_imagen = ?, alto_imagen = ?, fecha_subida = NOW(), usuario_subida = 1
            WHERE id = ?
        ");

        $stmt->execute([
            $nombre_original,
            $nombre_unico,
            $ruta_relativa,
            $extension,
            $bytes_escritos,
            mime_content_type($ruta_completa),
            $ancho,
            $alto,
            $archivo_existente['id']
        ]);

        $archivo_id = $archivo_existente['id'];
        logMessage("Archivo actualizado en BD con ID: $archivo_id");
    } else {
        // Insertar nuevo registro
        $stmt = $pdo->prepare("
            INSERT INTO archivos_campos_adicionales 
            (valor_campo_id, servicio_id, campo_id, nombre_original, nombre_almacenado, 
             ruta_archivo, extension, tamaño_bytes, tipo_mime, ancho_imagen, alto_imagen,
             fecha_subida, usuario_subida, activo)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW(), 1, 1)
        ");

        $stmt->execute([
            $valor_campo_id,
            $servicio_id,
            $campo_id,
            $nombre_original,
            $nombre_unico,
            $ruta_relativa,
            $extension,
            $bytes_escritos,
            mime_content_type($ruta_completa),
            $ancho,
            $alto
        ]);

        $archivo_id = $pdo->lastInsertId();
        logMessage("Nuevo archivo insertado en BD con ID: $archivo_id");
    }

    // ✅ VERIFICACIÓN FINAL
    $verificacion_final = file_exists($ruta_completa) ? "✅ EXISTE" : "❌ NO EXISTE";
    logMessage("VERIFICACIÓN FINAL: Archivo $ruta_completa - $verificacion_final");

    // Respuesta exitosa
    $response = [
        'success' => true,
        'message' => 'Archivo subido exitosamente',
        'datos' => [
            'archivo_id' => $archivo_id,
            'nombre_original' => $nombre_original,
            'nombre_almacenado' => $nombre_unico,
            'ruta_publica' => $ruta_relativa,
            'ruta_completa_debug' => $ruta_completa,
            'extension' => $extension,
            'tamaño_bytes' => $bytes_escritos,
            'servicio_id' => $servicio_id,
            'campo_id' => $campo_id,
            'verificacion_archivo_existe' => file_exists($ruta_completa)
        ]
    ];

    echo json_encode($response);
    logMessage("Respuesta enviada exitosamente");

} catch (Exception $e) {
    $errorMsg = 'Error subiendo archivo: ' . $e->getMessage();
    logMessage("ERROR: " . $errorMsg);
    logMessage("Stack trace: " . $e->getTraceAsString());

    // Eliminar archivo si se creó pero falló la BD
    if (isset($ruta_completa) && file_exists($ruta_completa)) {
        unlink($ruta_completa);
        logMessage("Archivo eliminado por error: $ruta_completa");
    }

    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'debug_info' => [
            'script_dir' => isset($script_dir) ? $script_dir : 'no definido',
            'carpeta_base' => isset($carpeta_base) ? $carpeta_base : 'no definido',
            'carpeta_destino' => isset($carpeta_destino) ? $carpeta_destino : 'no definido',
            'ruta_completa' => isset($ruta_completa) ? $ruta_completa : 'no definido'
        ]
    ]);
}

logMessage("=== FIN SUBIR ARCHIVO CAMPO ADICIONAL ===\n");
?>