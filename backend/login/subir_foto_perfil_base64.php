<?php
// Endpoint: subir_foto_perfil_base64.php
// Propósito: Recibe una imagen en base64, la guarda en una ruta pública
// y retorna una URL accesible junto con la ruta relativa.

require_once 'auth_middleware.php';

// Validar que la función existe antes de llamarla para evitar errores fatales (seguridad)
if (function_exists('setCORSHeaders')) {
  setCORSHeaders();
} else {
  header('Access-Control-Allow-Origin: *');
  header('Access-Control-Allow-Headers: Content-Type, Authorization');
  header('Access-Control-Allow-Methods: POST, OPTIONS');
  header('Content-Type: application/json; charset=utf-8');
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
  http_response_code(200);
  exit(0);
}

try {
  $currentUser = requireAuth();
} catch (Exception $e) {
  http_response_code(401);
  echo json_encode(['error' => 'Unauthorized']);
  exit;
}

function respond($code, $payload)
{
  http_response_code($code);
  echo json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
  exit;
}

try {
  $raw = file_get_contents('php://input');
  $json = json_decode($raw, true);
  if (!is_array($json)) {
    respond(400, [
      'success' => false,
      'error' => 'JSON inválido o no enviado',
    ]);
  }

  $base64 = $json['imagen_base64'] ?? null;
  $nombreArchivo = $json['nombre_archivo'] ?? null;
  $userId = $json['user_id'] ?? null;
  $descripcion = $json['descripcion'] ?? null;

  if (!$base64) {
    respond(422, [
      'success' => false,
      'error' => 'Campo requerido: imagen_base64',
    ]);
  }

  // Configuración básica (alineada con StaffConstants)
  $formatosPermitidos = ['jpg', 'jpeg', 'png'];
  $maxKB = 2048; // 2MB

  // Quitar prefijo data URI si existe
  if (strpos($base64, 'base64,') !== false) {
    $base64 = substr($base64, strpos($base64, 'base64,') + 7);
  }

  $bin = base64_decode($base64, true);
  if ($bin === false) {
    respond(422, [
      'success' => false,
      'error' => 'Cadena base64 inválida',
    ]);
  }

  $sizeKB = strlen($bin) / 1024;
  if ($sizeKB > $maxKB) {
    respond(413, [
      'success' => false,
      'error' => 'La imagen excede el máximo de ' . $maxKB . 'KB',
    ]);
  }

  // Determinar extensión
  $extension = 'jpg';
  if ($nombreArchivo) {
    $parts = explode('.', strtolower($nombreArchivo));
    if (count($parts) > 1) {
      $extCandidate = end($parts);
      if (in_array($extCandidate, $formatosPermitidos)) {
        $extension = $extCandidate;
      }
    }
  }

  // Generar nombre si no se envió
  if (!$nombreArchivo) {
    $ts = time();
    $nombreArchivo = 'staff_' . ($userId ?? $ts) . '_perfil_' . $ts . '.' . $extension;
  }

  // Ruta de destino (pública)
  $destDir = dirname(__DIR__) . '/uploads/staff/perfil';
  if (!is_dir($destDir)) {
    if (!mkdir($destDir, 0775, true)) {
      respond(500, [
        'success' => false,
        'error' => 'No se pudo crear el directorio de destino',
      ]);
    }
  }

  $destPath = $destDir . '/' . $nombreArchivo;
  if (file_put_contents($destPath, $bin) === false) {
    respond(500, [
      'success' => false,
      'error' => 'No se pudo guardar la imagen',
    ]);
  }

  // Construir ruta relativa y URL pública
  $rutaRelativa = 'uploads/staff/perfil/' . $nombreArchivo;
  $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
  $host = $_SERVER['HTTP_HOST'] ?? 'localhost';

  // Asegurar que basePath use slashes normales y no backslashes (común en Windows)
  $scriptDir = dirname($_SERVER['SCRIPT_NAME']);
  $basePath = rtrim(str_replace('\\', '/', $scriptDir), '/');

  // Usar el script proxy para servir la imagen con CORS correcto
  $urlPublica = $scheme . '://' . $host . $basePath . '/ver_imagen.php?ruta=' . $rutaRelativa;

  respond(200, [
    'success' => true,
    'status' => 'ok',
    'message' => 'Foto subida correctamente',
    'data' => [
      'user_id' => $userId,
      'nombre_archivo' => $nombreArchivo,
      'descripcion' => $descripcion,
      'tamano_kb' => round($sizeKB, 2),
    ],
    'url' => $urlPublica,
    'ruta' => $rutaRelativa,
  ]);
} catch (Throwable $e) {
  respond(500, [
    'success' => false,
    'error' => 'Error interno: ' . $e->getMessage(),
  ]);
}
