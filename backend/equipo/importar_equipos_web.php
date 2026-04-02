<?php
// timportar_equipos_web.php
// Versión completa con JWT, logging robusto y CORS

// ============================================
// CONFIGURACIÓN DE LOGGING
// ============================================

define('LOG_DIR', __DIR__ . '/logs');
define('LOG_FILE', LOG_DIR . '/timportar_equipos_web_' . date('Y-m-d') . '.log');

// Crear directorio de logs si no existe
if (!is_dir(LOG_DIR)) {
    mkdir(LOG_DIR, 0777, true);
}

/**
 * Función de logging robusto
 */
function log_message($level, $message, $data = null) {
    $timestamp = date('Y-m-d H:i:s.u');
    $pid = getmypid();
    
    $log_entry = "[$timestamp] [PID:$pid] [$level] $message";
    
    if ($data !== null) {
        if (is_array($data) || is_object($data)) {
            $log_entry .= "\n  Data: " . json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES);
        } else {
            $log_entry .= "\n  Data: $data";
        }
    }
    
    $log_entry .= "\n";
    
    // Escribir a archivo
    file_put_contents(LOG_FILE, $log_entry, FILE_APPEND | LOCK_EX);
}

// ============================================
// HEADERS CORS
// ============================================

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS, GET");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

// Manejar preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    log_message('INFO', 'Petición OPTIONS (preflight)');
    http_response_code(200);
    exit(0);
}

// ============================================
// VALIDAR MÉTODO HTTP
// ============================================

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    log_message('WARN', 'Método HTTP no permitido', $_SERVER['REQUEST_METHOD']);
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Método no permitido, use POST']);
    exit;
}

// ============================================
// CONFIGURACIÓN DE ERROR HANDLING
// ============================================

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);
ini_set('error_log', LOG_FILE);

// Set custom error handler
set_error_handler(function($errno, $errstr, $errfile, $errline) {
    $error_type = match($errno) {
        E_ERROR => 'ERROR',
        E_WARNING => 'WARNING',
        E_NOTICE => 'NOTICE',
        E_DEPRECATED => 'DEPRECATED',
        default => 'UNKNOWN'
    };
    
    log_message($error_type, "$errstr in $errfile:$errline");
    return false;
});

// ============================================
// BUFFER DE OUTPUT
// ============================================

ob_start();
log_message('INFO', '=== NUEVA SOLICITUD DE IMPORTACIÓN WEB ===');

// ============================================
// AUTENTICACIÓN JWT
// ============================================

log_message('INFO', 'Iniciando autenticación JWT');

try {
    require_once '../login/auth_middleware.php';
    log_message('DEBUG', 'auth_middleware.php cargado exitosamente');
} catch (Exception $e) {
    log_message('ERROR', 'Error al cargar auth_middleware.php', $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error de configuración']);
    exit;
}

try {
    $currentUser = requireAuth();
    log_message('INFO', 'Usuario autenticado', [
        'usuario' => $currentUser['usuario'],
        'rol' => $currentUser['rol']
    ]);
} catch (Exception $e) {
    log_message('WARN', 'Autenticación fallida', $e->getMessage());
    ob_clean();
    http_response_code(401);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

// ============================================
// CONEXIÓN A BASE DE DATOS
// ============================================

log_message('INFO', 'Conectando a la base de datos');

try {
    require '../conexion.php';
    log_message('DEBUG', 'conexion.php cargado');
} catch (Exception $e) {
    log_message('ERROR', 'Error al cargar conexion.php', $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error de configuración de BD']);
    exit;
}

if (!isset($conn)) {
    log_message('ERROR', 'Variable $conn no está definida');
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Conexión no inicializada']);
    exit;
}

if ($conn->connect_error) {
    log_message('ERROR', 'Error de conexión a BD', $conn->connect_error);
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error de conexión a base de datos']);
    exit;
}

log_message('INFO', 'Conexión a BD establecida');

// ============================================
// CARGAR PHPSPREADSHEET
// ============================================

log_message('INFO', 'Buscando vendor/autoload.php');

$vendorPath = null;
$paths_checked = [];

// Opción 1: En el mismo directorio
$path1 = __DIR__ . '/vendor/autoload.php';
$paths_checked[] = ['path' => $path1, 'exists' => file_exists($path1)];
if (file_exists($path1)) {
    $vendorPath = $path1;
    log_message('DEBUG', 'Vendor encontrado en opción 1', $path1);
}

// Opción 2: Un nivel arriba
if (!$vendorPath) {
    $path2 = __DIR__ . '/../vendor/autoload.php';
    $paths_checked[] = ['path' => $path2, 'exists' => file_exists($path2)];
    if (file_exists($path2)) {
        $vendorPath = $path2;
        log_message('DEBUG', 'Vendor encontrado en opción 2', $path2);
    }
}

// Opción 3: Dos niveles arriba
if (!$vendorPath) {
    $path3 = __DIR__ . '/../../vendor/autoload.php';
    $paths_checked[] = ['path' => $path3, 'exists' => file_exists($path3)];
    if (file_exists($path3)) {
        $vendorPath = $path3;
        log_message('DEBUG', 'Vendor encontrado en opción 3', $path3);
    }
}

// Opción 4: En DOCUMENT_ROOT
if (!$vendorPath && isset($_SERVER['DOCUMENT_ROOT'])) {
    $path4 = $_SERVER['DOCUMENT_ROOT'] . '/vendor/autoload.php';
    $paths_checked[] = ['path' => $path4, 'exists' => file_exists($path4)];
    if (file_exists($path4)) {
        $vendorPath = $path4;
        log_message('DEBUG', 'Vendor encontrado en opción 4', $path4);
    }
}

log_message('INFO', 'Rutas de vendor verificadas', $paths_checked);

if (!$vendorPath) {
    log_message('ERROR', 'No se encontró vendor/autoload.php', $paths_checked);
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'error' => 'PhpSpreadsheet no configurado',
        'details' => 'vendor/autoload.php no encontrado'
    ]);
    exit;
}

log_message('INFO', 'Cargando vendor', ['path' => $vendorPath]);

try {
    require_once $vendorPath;
    log_message('DEBUG', 'vendor/autoload.php cargado exitosamente');
} catch (Exception $e) {
    log_message('ERROR', 'Error al cargar vendor/autoload.php', $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error al cargar librerías']);
    exit;
}

// Verificar que PhpSpreadsheet esté disponible
if (!class_exists('PhpOffice\PhpSpreadsheet\IOFactory')) {
    log_message('ERROR', 'PhpOffice\PhpSpreadsheet\IOFactory no está disponible');
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'PhpSpreadsheet no disponible']);
    exit;
}

log_message('INFO', 'PhpSpreadsheet cargado correctamente');

use PhpOffice\PhpSpreadsheet\IOFactory;

// ============================================
// OBTENER DATOS DEL REQUEST
// ============================================

log_message('INFO', 'Leyendo datos del request');

$raw_input = file_get_contents('php://input');
log_message('DEBUG', 'Input recibido (primeros 500 caracteres)', substr($raw_input, 0, 500));

$input = json_decode($raw_input, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    log_message('WARN', 'Error al decodificar JSON', json_last_error_msg());
    ob_clean();
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'JSON inválido']);
    exit;
}

log_message('DEBUG', 'Input decodificado');

// ============================================
// VALIDAR ENTRADA
// ============================================

log_message('INFO', 'Validando entrada');

if (!isset($input['archivo_base64']) || empty($input['archivo_base64'])) {
    log_message('WARN', 'No se recibió archivo_base64');
    ob_clean();
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'No se recibió archivo']);
    exit;
}

$nombreArchivo = $input['nombre_archivo'] ?? 'archivo_importacion.xlsx';
log_message('INFO', 'Archivo recibido', ['nombre' => $nombreArchivo]);

// ============================================
// DECODIFICAR Y CARGAR ARCHIVO
// ============================================

log_message('INFO', 'Decodificando archivo base64');

try {
    $fileData = base64_decode($input['archivo_base64'], true);
    
    if ($fileData === false) {
        throw new Exception('Error al decodificar base64');
    }
    
    log_message('INFO', 'Archivo decodificado', ['tamaño' => strlen($fileData) . ' bytes']);
    
    // Crear archivo temporal
    $tempFile = tempnam(sys_get_temp_dir(), 'timport_equipos_');
    
    if (!$tempFile) {
        throw new Exception('No se pudo crear archivo temporal');
    }
    
    $bytesWritten = file_put_contents($tempFile, $fileData);
    log_message('DEBUG', 'Archivo temporal creado', ['ruta' => $tempFile, 'bytes' => $bytesWritten]);
    
    // Cargar spreadsheet
    log_message('INFO', 'Cargando spreadsheet desde archivo temporal');
    
    $spreadsheet = IOFactory::load($tempFile);
    $sheet = $spreadsheet->getActiveSheet();
    $data = $sheet->toArray();
    
    log_message('INFO', 'Spreadsheet cargado', ['filas' => count($data)]);
    
    // Limpiar archivo temporal
    unlink($tempFile);
    log_message('DEBUG', 'Archivo temporal eliminado');
    
} catch (Exception $e) {
    log_message('ERROR', 'Error al cargar archivo', $e->getMessage());
    ob_clean();
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error al procesar archivo: ' . $e->getMessage()]);
    exit;
}

// ============================================
// VALIDAR FORMATO
// ============================================

log_message('INFO', 'Validando formato del archivo');

if (empty($data) || count($data[0]) < 5) {
    log_message('WARN', 'Formato inválido', ['columnas' => count($data[0] ?? [])]);
    ob_clean();
    http_response_code(400);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Formato de archivo inválido. Use la plantilla correcta.']);
    exit;
}

log_message('INFO', 'Formato validado correctamente');

// ============================================
// PROCESAR DATOS
// ============================================

log_message('INFO', 'Iniciando procesamiento de datos');

try {
    $conn->autocommit(FALSE);
    log_message('DEBUG', 'Transacción iniciada');
    
    $insertados = 0;
    $actualizados = 0;
    $errores = 0;
    $erroresDetalle = [];
    
    // Procesar datos (saltando header - fila 0)
    for ($i = 1; $i < count($data); $i++) {
        $row = $data[$i];
        $numeroFila = $i + 1;
        
        // Saltar filas completamente vacías
        if (empty(array_filter($row))) {
            log_message('DEBUG', "Fila $numeroFila vacía, saltando");
            continue;
        }
        
        // Validar datos mínimos
        if (empty(trim($row[1] ?? '')) || empty(trim($row[4] ?? '')) || empty(trim($row[9] ?? ''))) {
            log_message('WARN', "Fila $numeroFila: Faltan campos obligatorios");
            $errores++;
            $erroresDetalle[] = "Fila $numeroFila: Faltan campos obligatorios (Nombre, Placa o Empresa)";
            continue;
        }
        
        $nombre = trim($row[1]);
        $modelo = trim($row[2] ?? '');
        $marca = trim($row[3] ?? '');
        $placa = trim($row[4]);
        $codigo = trim($row[5] ?? '');
        $ciudad = trim($row[6] ?? '');
        $planta = trim($row[7] ?? '');
        $linea_prod = trim($row[8] ?? '');
        $nombre_empresa = trim($row[9]);
        $usuario_registro = trim($row[10] ?? $currentUser['usuario']);
        $estado_id = !empty(trim($row[11] ?? '')) ? (int)trim($row[11]) : null;
        
        log_message('DEBUG', "Procesando fila $numeroFila", [
            'nombre' => $nombre,
            'placa' => $placa,
            'empresa' => $nombre_empresa
        ]);
        
        // Verificar si existe por placa
        $stmt = $conn->prepare("SELECT id FROM equipos WHERE placa = ? AND activo = 1");
        $stmt->bind_param("s", $placa);
        $stmt->execute();
        $result = $stmt->get_result();
        
        if ($result->num_rows > 0) {
            // Actualizar existente
            $equipo = $result->fetch_assoc();
            
            log_message('DEBUG', "Fila $numeroFila: Actualizando equipo ID " . $equipo['id']);
            
            $stmt = $conn->prepare("
                UPDATE equipos SET 
                    nombre = ?, modelo = ?, marca = ?, codigo = ?, 
                    ciudad = ?, planta = ?, linea_prod = ?, nombre_empresa = ?, estado_id = ?
                WHERE id = ?
            ");
            
            $stmt->bind_param("ssssssssii", 
                $nombre, $modelo, $marca, $codigo, 
                $ciudad, $planta, $linea_prod, $nombre_empresa, 
                $estado_id, $equipo['id']
            );
            
            if ($stmt->execute()) {
                $actualizados++;
                log_message('DEBUG', "Fila $numeroFila: Actualización exitosa");
            } else {
                $errores++;
                $error_msg = $stmt->error;
                log_message('ERROR', "Fila $numeroFila: Error al actualizar", $error_msg);
                $erroresDetalle[] = "Fila $numeroFila: Error al actualizar - $error_msg";
            }
            $stmt->close();
        } else {
            // Insertar nuevo
            log_message('DEBUG', "Fila $numeroFila: Insertando nuevo equipo");
            
            $stmt = $conn->prepare("
                INSERT INTO equipos (nombre, modelo, marca, placa, codigo, 
                                   ciudad, planta, linea_prod, nombre_empresa, 
                                   usuario_registro, activo, estado_id) 
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)
            ");
            
            $stmt->bind_param("ssssssssssi", 
                $nombre, $modelo, $marca, $placa, $codigo,
                $ciudad, $planta, $linea_prod, $nombre_empresa, $usuario_registro, $estado_id
            );
            
            if ($stmt->execute()) {
                $insertados++;
                log_message('DEBUG', "Fila $numeroFila: Inserción exitosa");
            } else {
                $errores++;
                $error_msg = $stmt->error;
                log_message('ERROR', "Fila $numeroFila: Error al insertar", $error_msg);
                $erroresDetalle[] = "Fila $numeroFila: Error al insertar - $error_msg";
            }
            $stmt->close();
        }
    }
    
    // Confirmar transacción
    $conn->commit();
    log_message('INFO', 'Transacción confirmada', [
        'insertados' => $insertados,
        'actualizados' => $actualizados,
        'errores' => $errores
    ]);
    
} catch (Exception $e) {
    log_message('ERROR', 'Error durante procesamiento', $e->getMessage());
    $conn->rollback();
    log_message('DEBUG', 'Transacción revertida');
    
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error al procesar datos: ' . $e->getMessage()]);
    exit;
}

// ============================================
// RESPUESTA FINAL
// ============================================

log_message('INFO', 'Importación completada exitosamente');

$mensaje = "Importación completada: $insertados nuevos, $actualizados actualizados";
if ($errores > 0) {
    $mensaje .= ", $errores errores";
}

ob_clean();
http_response_code(200);
header('Content-Type: application/json');

$response = [
    'success' => true,
    'message' => $mensaje,
    'insertados' => $insertados,
    'actualizados' => $actualizados,
    'errores' => $errores,
    'usuario_registro' => $currentUser['usuario']
];

if (!empty($erroresDetalle)) {
    $response['errores_detalle'] = $erroresDetalle;
}

log_message('INFO', 'Respuesta enviada', $response);

echo json_encode($response);

// ============================================
// LIMPIEZA
// ============================================

if (isset($conn)) {
    $conn->close();
    log_message('DEBUG', 'Conexión a BD cerrada');
}

exit;
?>