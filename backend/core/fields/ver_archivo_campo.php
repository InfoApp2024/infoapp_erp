<?php
require_once '../../login/auth_middleware.php';

// Servir archivos de campos adicionales de forma segura - VERSIÓN MEJORADA


try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    exit;
}

// ✅ FUNCIÓN PARA DEBUG
function debug_log($mensaje)
{
    error_log("[VER_ARCHIVO_CAMPO] " . $mensaje);
}

try {
    debug_log("=== INICIO SOLICITUD ===");

    // Validar parámetros
    if (!isset($_GET['ruta'])) {
        throw new Exception('Parámetro ruta requerido');
    }

    $ruta_solicitada = $_GET['ruta'];
    debug_log("Ruta solicitada: " . $ruta_solicitada);

    // ✅ VALIDACIÓN MÁS FLEXIBLE DE RUTAS
    $patrones_validos = [
        '/^uploads\/campos_adicionales\/(imagenes|archivos)\/[a-zA-Z0-9_\-\.]+$/',
        '/^uploads\/[a-zA-Z0-9_\-\.\/]+$/', // Para compatibilidad
        '/^campos_adicionales\/(imagenes|archivos)\/[a-zA-Z0-9_\-\.]+$/', // Sin uploads/
    ];

    $ruta_valida = false;
    foreach ($patrones_validos as $patron) {
        if (preg_match($patron, $ruta_solicitada)) {
            $ruta_valida = true;
            break;
        }
    }

    if (!$ruta_valida) {
        debug_log("Ruta no válida: " . $ruta_solicitada);
        throw new Exception('Ruta no válida: ' . $ruta_solicitada);
    }

    // ✅ INTENTAR MÚLTIPLES UBICACIONES
    $rutas_posibles = [
        $ruta_solicitada,                           // Ruta directa
        '../' . $ruta_solicitada,                  // Un nivel arriba
        './' . $ruta_solicitada,                   // Directorio actual
        'uploads/' . basename($ruta_solicitada),    // En uploads local
        '../uploads/' . basename($ruta_solicitada), // uploads un nivel arriba
        // ✅ NUEVAS RUTAS ADICIONALES
        str_replace('uploads/', '', $ruta_solicitada), // Sin uploads/
        '../' . str_replace('uploads/', '', $ruta_solicitada), // Sin uploads/ un nivel arriba
    ];

    $ruta_completa = null;
    foreach ($rutas_posibles as $ruta_test) {
        debug_log("Probando ruta: " . $ruta_test);
        if (file_exists($ruta_test) && is_file($ruta_test)) {
            $ruta_completa = $ruta_test;
            debug_log("✅ Archivo encontrado en: " . $ruta_completa);
            break;
        }
    }

    if (!$ruta_completa) {
        debug_log("❌ Archivo no encontrado en ninguna ubicación");
        debug_log("Rutas probadas: " . implode(", ", $rutas_posibles));
        debug_log("Directorio actual: " . getcwd());
        debug_log("Contenido directorio actual: " . implode(", ", scandir('.')));

        // ✅ INTENTAR LISTAR DIRECTORIOS PARA DEBUG
        if (is_dir('uploads')) {
            debug_log("Contenido uploads/: " . implode(", ", scandir('uploads')));
        }
        if (is_dir('../uploads')) {
            debug_log("Contenido ../uploads/: " . implode(", ", scandir('../uploads')));
        }
        if (is_dir('uploads/campos_adicionales')) {
            debug_log("Contenido uploads/campos_adicionales/: " . implode(", ", scandir('uploads/campos_adicionales')));
        }

        throw new Exception('Archivo no encontrado: ' . $ruta_solicitada);
    }

    // ✅ VALIDACIONES DE SEGURIDAD ADICIONALES
    $ruta_real = realpath($ruta_completa);
    if (!$ruta_real) {
        throw new Exception('Error resolviendo ruta real');
    }

    // Verificar que no se sale del directorio permitido
    $directorio_base = realpath('.');
    $directorio_padre = realpath('..');

    // Permitir acceso tanto al directorio actual como al padre
    if (strpos($ruta_real, $directorio_base) !== 0 && strpos($ruta_real, $directorio_padre) !== 0) {
        debug_log("❌ Intento de acceso fuera de directorios permitidos");
        debug_log("Ruta real: $ruta_real");
        debug_log("Directorio base: $directorio_base");
        debug_log("Directorio padre: $directorio_padre");
        throw new Exception('Acceso denegado');
    }

    // Obtener información del archivo
    $tipo_mime = mime_content_type($ruta_real);
    $tamaño = filesize($ruta_real);
    $nombre_archivo = basename($ruta_real);

    debug_log("Archivo: $nombre_archivo, Tipo: $tipo_mime, Tamaño: $tamaño bytes");

    // ✅ MEJORAR DETECCIÓN DE TIPO MIME
    if (!$tipo_mime || $tipo_mime === 'application/octet-stream') {
        $extension = strtolower(pathinfo($nombre_archivo, PATHINFO_EXTENSION));
        $tipos_mime = [
            'jpg' => 'image/jpeg',
            'jpeg' => 'image/jpeg',
            'png' => 'image/png',
            'gif' => 'image/gif',
            'bmp' => 'image/bmp',
            'webp' => 'image/webp',
            'svg' => 'image/svg+xml',
            'pdf' => 'application/pdf',
            'doc' => 'application/msword',
            'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
            'xls' => 'application/vnd.ms-excel',
            'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            'ppt' => 'application/vnd.ms-powerpoint',
            'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
            'txt' => 'text/plain',
            'csv' => 'text/csv',
            'zip' => 'application/zip',
            'rar' => 'application/x-rar-compressed',
            'mp4' => 'video/mp4',
            'mp3' => 'audio/mp3',
            'wav' => 'audio/wav',
        ];

        if (isset($tipos_mime[$extension])) {
            $tipo_mime = $tipos_mime[$extension];
            debug_log("Tipo MIME corregido a: $tipo_mime");
        } else {
            $tipo_mime = 'application/octet-stream';
            debug_log("Usando tipo MIME genérico: $tipo_mime");
        }
    }

    // ✅ HEADERS MEJORADOS
    header("Content-Type: $tipo_mime");
    header("Content-Length: $tamaño");
    header("Cache-Control: public, max-age=3600");
    header("Last-Modified: " . gmdate('D, d M Y H:i:s', filemtime($ruta_real)) . ' GMT');
    header("ETag: \"" . md5_file($ruta_real) . "\"");

    // ✅ DETERMINAR SI MOSTRAR INLINE O COMO DESCARGA
    $mostrar_inline = false;

    // Parámetro para forzar descarga
    if (isset($_GET['download']) && $_GET['download'] === '1') {
        $mostrar_inline = false;
        debug_log("Forzando descarga por parámetro");
    } else {
        // Mostrar inline para imágenes, PDFs y texto
        $tipos_inline = ['image/', 'application/pdf', 'text/'];
        foreach ($tipos_inline as $tipo) {
            if (strpos($tipo_mime, $tipo) === 0) {
                $mostrar_inline = true;
                break;
            }
        }
    }

    if ($mostrar_inline) {
        header("Content-Disposition: inline; filename=\"$nombre_archivo\"");
        debug_log("Mostrando inline: $nombre_archivo");
    } else {
        header("Content-Disposition: attachment; filename=\"$nombre_archivo\"");
        debug_log("Forzando descarga: $nombre_archivo");
    }

    // ✅ MANEJO DE RANGOS PARA ARCHIVOS GRANDES
    if (isset($_SERVER['HTTP_RANGE'])) {
        debug_log("Solicitud de rango detectada: " . $_SERVER['HTTP_RANGE']);

        $range = $_SERVER['HTTP_RANGE'];
        $ranges = explode('=', $range);
        $offsets = explode('-', $ranges[1]);
        $offset = intval($offsets[0]);
        $length = intval($offsets[1]) - $offset;

        if (!$length) {
            $length = $tamaño - $offset;
        }

        header('HTTP/1.1 206 Partial Content');
        header("Content-Range: bytes $offset-" . ($offset + $length - 1) . "/$tamaño");
        header("Content-Length: $length");

        $file = fopen($ruta_real, 'r');
        fseek($file, $offset);
        echo fread($file, $length);
        fclose($file);
    } else {
        // ✅ ENVIAR ARCHIVO COMPLETO CON MANEJO DE ERRORES
        debug_log("Enviando archivo completo: $nombre_archivo");

        // Verificar que el archivo sigue existiendo
        if (!file_exists($ruta_real)) {
            throw new Exception('El archivo desapareció durante el procesamiento');
        }

        // Limpiar cualquier output previo
        if (ob_get_level()) {
            ob_end_clean();
        }

        // Enviar archivo
        $resultado = readfile($ruta_real);

        if ($resultado === false) {
            throw new Exception('Error leyendo el archivo');
        }

        debug_log("✅ Archivo enviado exitosamente. Bytes: $resultado");
    }

} catch (Exception $e) {
    debug_log("❌ ERROR: " . $e->getMessage());

    // Limpiar cualquier output previo
    if (ob_get_level()) {
        ob_end_clean();
    }

    http_response_code(404);
    header('Content-Type: application/json');

    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage(),
        'debug_info' => [
            'ruta_solicitada' => $_GET['ruta'] ?? 'no_especificada',
            'directorio_actual' => getcwd(),
            'timestamp' => date('Y-m-d H:i:s')
        ]
    ]);
}
?>