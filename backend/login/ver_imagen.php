<?php
// ver_imagen.php - Proxy para servir imágenes de perfil con CORS habilitado
// No requiere autenticación para permitir que Image.network funcione sin headers adicionales

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', __DIR__ . '/error_log_imagen.txt');

// Función de logging
function debug_log($message)
{
    file_put_contents(__DIR__ . '/debug_ver_imagen.txt', date('[Y-m-d H:i:s] ') . $message . PHP_EOL, FILE_APPEND);
}

require_once 'auth_middleware.php';

// Validar que la función existe antes de llamarla para evitar errores fatales si el include falla
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
} else {
    // Fallback manual si falla el middleware
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: GET, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization");
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // Imagen pública (o protegida opcionalmente), permitimos visualización sin token
    $currentUser = optionalAuth();
} catch (Exception $e) {
    // Si falla el token (ej: mal formado), igual permitimos ver la imagen si es pública? 
    // Mejor no, si hay un error de auth real, optionalAuth retorna null, no lanza excepción usualmente, salvo error grave.
    // Pero si optionalAuth() no existe (error en archivo), atrapamos.
    $currentUser = null;
}

// Obtener ruta o nombre de archivo
$ruta = $_GET['ruta'] ?? null;
$nombre = $_GET['nombre'] ?? null;

debug_log("Request received. Ruta: " . ($ruta ?? 'null') . ", Nombre: " . ($nombre ?? 'null'));

if (!$ruta && !$nombre) {
    debug_log("Error: Ruta o nombre faltante");
    http_response_code(400);
    die('Ruta o nombre de archivo requerido');
}

// Directorio base global (backend)
$backendDir = dirname(__DIR__);

// Determinar la ruta completa del archivo
$rutaCompleta = '';
$fileFound = false;

// Normalizar la ruta de entrada
$ruta = str_replace(['\\', '../', '..\\'], '/', $ruta);
$ruta = ltrim($ruta, '/'); // Quitar slash inicial

// Lista de posibles ubicaciones
$posiblesRutas = [
    // 1. Ruta absoluta desde backend (lo más probable)
    $backendDir . '/' . $ruta,

    // 2. Ruta asumiendo que 'uploads' está en el mismo directorio que este script (legacy/fallback)
    __DIR__ . '/' . $ruta,

    // 3. Fallback: Si enviaron solo nombre, buscar en ruta estándar
    $backendDir . '/uploads/staff/perfil/' . basename($ruta)
];

// Depuración
debug_log("Buscando archivo: " . $ruta);

foreach ($posiblesRutas as $path) {
    if (file_exists($path) && is_file($path)) {
        $rutaCompleta = $path;
        $fileFound = true;
        debug_log("Archivo encontrado en: " . $path);
        break;
    } else {
        debug_log("No encontrado en: " . $path);
    }
}

if (!$fileFound) {
    debug_log("Error: Archivo no existe en ninguna ubicación.");
    http_response_code(404);
    die('Imagen no encontrada');
}

// Verificar que el archivo está dentro del directorio permitido (seguridad adicional)
$realPath = realpath($rutaCompleta);
// Nota: realpath puede fallar si el archivo no existe, pero ya verificamos file_exists

debug_log("RealPath: " . ($realPath ?: 'false'));

$extension = strtolower(pathinfo($rutaCompleta, PATHINFO_EXTENSION));
$extensiones_validas = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'svg'];

if (!in_array($extension, $extensiones_validas)) {
    debug_log("Error: Extension no valida: " . $extension);
    http_response_code(403);
    die('Tipo de archivo no permitido');
}

// Determinar tipo MIME
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

// Enviar headers
header('Content-Type: ' . $content_type);
header('Content-Length: ' . filesize($rutaCompleta));
header('Cache-Control: public, max-age=86400'); // Cache por 1 día
header('Pragma: public');

debug_log("Sirviendo archivo con Content-Type: " . $content_type);

// Enviar archivo
readfile($rutaCompleta);
