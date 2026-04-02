<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    
    // PASO 2: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    // PASO 3: Obtener y validar ruta
    $ruta = $_GET['ruta'] ?? null;
    
    if (!$ruta) {
        http_response_code(400);
        die('Ruta de imagen requerida');
    }
    
    // PASO 4: Sanitizar la ruta para seguridad
    $ruta = str_replace('..', '', $ruta);
    $ruta = ltrim($ruta, '/'); // Remover slash inicial si existe
    
    // PASO 5: Construir ruta completa desde la raíz del proyecto
    $rutaCompleta = '../' . $ruta;
    
    // PASO 6: Log de acceso
    logAccess($currentUser, '/ver_imagen.php', 'view_image', [
        'ruta_solicitada' => $ruta,
        'ruta_completa' => $rutaCompleta
    ]);
    
    // PASO 7: Verificar que el archivo existe
    if (!file_exists($rutaCompleta)) {
        error_log("Imagen no encontrada: $rutaCompleta");
        http_response_code(404);
        die('Imagen no encontrada');
    }
    
    // PASO 8: Verificar que es realmente una imagen
    $extension = strtolower(pathinfo($rutaCompleta, PATHINFO_EXTENSION));
    $extensiones_validas = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];
    
    if (!in_array($extension, $extensiones_validas)) {
        http_response_code(403);
        die('Tipo de archivo no permitido');
    }
    
    // PASO 9: Verificar que el archivo pertenece a un directorio permitido
    $directorios_permitidos = [
        'uploads/servicios/fotos/',
        'uploads/campos_adicionales/imagenes/',
        'uploads/branding/',
        'uploads/logos/'
    ];
    
    $ruta_permitida = false;
    foreach ($directorios_permitidos as $directorio) {
        if (strpos($ruta, $directorio) === 0) {
            $ruta_permitida = true;
            break;
        }
    }
    
    if (!$ruta_permitida) {
        error_log("Acceso denegado a directorio no permitido: $ruta");
        http_response_code(403);
        die('Acceso denegado al directorio solicitado');
    }
    
    // PASO 10: Determinar tipo MIME
    $mime_types = [
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png' => 'image/png',
        'gif' => 'image/gif',
        'webp' => 'image/webp',
        'bmp' => 'image/bmp',
        'svg' => 'image/svg+xml'
    ];
    
    $content_type = $mime_types[$extension] ?? 'image/jpeg';
    
    // PASO 11: Enviar headers de imagen
    header('Content-Type: ' . $content_type);
    header('Content-Length: ' . filesize($rutaCompleta));
    header('Cache-Control: public, max-age=3600');
    header('Last-Modified: ' . gmdate('D, d M Y H:i:s', filemtime($rutaCompleta)) . ' GMT');
    header('ETag: "' . md5_file($rutaCompleta) . '"');
    
    // PASO 12: Verificar If-None-Match (cache del navegador)
    $etag = md5_file($rutaCompleta);
    if (isset($_SERVER['HTTP_IF_NONE_MATCH']) && $_SERVER['HTTP_IF_NONE_MATCH'] === '"' . $etag . '"') {
        http_response_code(304);
        exit;
    }
    
    // PASO 13: Enviar archivo
    readfile($rutaCompleta);
    
} catch (Exception $e) {
    error_log("Error en ver_imagen.php: " . $e->getMessage());
    http_response_code(500);
    echo 'Error interno del servidor';
}
?>