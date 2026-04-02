<?php
// exportar_equipos.php
// Versión con logging robusto para identificar errores

// ============================================
// CONFIGURACIÓN DE LOGGING
// ============================================

define('LOG_DIR', __DIR__ . '/logs');
define('LOG_FILE', LOG_DIR . '/exportar_equipos_' . date('Y-m-d') . '.log');

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
    
    // También a error_log de PHP
    error_log($log_entry);
}

/**
 * Registrar información del servidor
 */
function log_server_info() {
    log_message('INFO', '=== NUEVA SOLICITUD DE EXPORTACIÓN ===');
    log_message('INFO', 'Método HTTP: ' . $_SERVER['REQUEST_METHOD']);
    log_message('INFO', 'URL: ' . $_SERVER['REQUEST_URI']);
    log_message('INFO', 'IP: ' . ($_SERVER['REMOTE_ADDR'] ?? 'UNKNOWN'));
    log_message('INFO', 'User-Agent: ' . ($_SERVER['HTTP_USER_AGENT'] ?? 'UNKNOWN'));
    log_message('INFO', 'Script: ' . __FILE__);
    log_message('INFO', 'Script Dir: ' . __DIR__);
    log_message('INFO', 'PHP Version: ' . phpversion());
    log_message('INFO', 'Memory: ' . (memory_get_usage(true) / 1024 / 1024) . ' MB');
}

// ============================================
// HEADERS CORS
// ============================================

log_message('INFO', 'Estableciendo headers CORS');

header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Methods: POST, OPTIONS, GET");
header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");

log_message('DEBUG', 'Headers CORS establecidos');

// ============================================
// MANEJAR PREFLIGHT OPTIONS
// ============================================

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
    
    // No interrumpir, permitir que continue
    return false;
});

// ============================================
// BUFFER DE OUTPUT
// ============================================

ob_start();
log_message('INFO', 'Output buffer iniciado');

log_server_info();

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
    echo json_encode([
        'error' => 'Error de configuración',
        'details' => 'No se pudo cargar auth_middleware.php'
    ]);
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
    echo json_encode([
        'error' => 'No autorizado',
        'details' => $e->getMessage()
    ]);
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

log_message('INFO', 'Conexión a BD establecida', [
    'host' => $conn->server_info ?? 'unknown',
    'database' => $conn->select_db ?? 'unknown'
]);

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

// Opción 5: En el parent del DOCUMENT_ROOT
if (!$vendorPath && isset($_SERVER['DOCUMENT_ROOT'])) {
    $path5 = dirname($_SERVER['DOCUMENT_ROOT']) . '/vendor/autoload.php';
    $paths_checked[] = ['path' => $path5, 'exists' => file_exists($path5)];
    if (file_exists($path5)) {
        $vendorPath = $path5;
        log_message('DEBUG', 'Vendor encontrado en opción 5', $path5);
    }
}

log_message('INFO', 'Rutas de vendor verificadas', $paths_checked);

if (!$vendorPath) {
    log_message('ERROR', 'No se encontró vendor/autoload.php en ninguna ruta', $paths_checked);
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'error' => 'PhpSpreadsheet no configurado',
        'details' => 'vendor/autoload.php no encontrado',
        'paths_checked' => $paths_checked
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
if (!class_exists('PhpOffice\PhpSpreadsheet\Spreadsheet')) {
    log_message('ERROR', 'PhpOffice\PhpSpreadsheet\Spreadsheet no está disponible');
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'PhpSpreadsheet no disponible']);
    exit;
}

log_message('INFO', 'PhpSpreadsheet cargado correctamente');

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use PhpOffice\PhpSpreadsheet\Writer\Xlsx;

// ============================================
// OBTENER DATOS DEL REQUEST
// ============================================

log_message('INFO', 'Leyendo datos del request');

$raw_input = file_get_contents('php://input');
log_message('DEBUG', 'Input recibido', substr($raw_input, 0, 500));

$input = json_decode($raw_input, true);

if (json_last_error() !== JSON_ERROR_NONE) {
    log_message('WARN', 'Error al decodificar JSON', json_last_error_msg());
    $input = [];
}

log_message('DEBUG', 'Input decodificado', $input);

// ============================================
// OBTENER EQUIPOS
// ============================================

log_message('INFO', 'Obteniendo equipos para exportar');

$equipos = [];

if (isset($input['equipos']) && !empty($input['equipos']) && is_array($input['equipos'])) {
    // Equipos específicos seleccionados
    $equipos = $input['equipos'];
    log_message('INFO', 'Exportar equipos seleccionados', ['cantidad' => count($equipos)]);
} else {
    // Todos los equipos activos
    log_message('INFO', 'Exportar todos los equipos activos');
    
    $sql = "SELECT 
                id, nombre, modelo, marca, placa, codigo, ciudad, 
                planta, linea_prod, nombre_empresa, usuario_registro,
                activo, estado_id
            FROM equipos 
            WHERE activo = 1 
            ORDER BY nombre_empresa, nombre";
    
    log_message('DEBUG', 'Ejecutando query', $sql);
    
    try {
        $result = $conn->query($sql);
        
        if (!$result) {
            throw new Exception('Query fallida: ' . $conn->error);
        }
        
        log_message('DEBUG', 'Query ejecutada', ['rows' => $result->num_rows]);
        
        if ($result->num_rows > 0) {
            while ($row = $result->fetch_assoc()) {
                $equipos[] = $row;
            }
        }
        
        log_message('INFO', 'Equipos obtenidos', ['cantidad' => count($equipos)]);
    } catch (Exception $e) {
        log_message('ERROR', 'Error al obtener equipos', $e->getMessage());
        ob_clean();
        http_response_code(500);
        header('Content-Type: application/json');
        echo json_encode(['error' => 'Error al obtener equipos']);
        exit;
    }
}

// Validar que haya datos
if (empty($equipos)) {
    log_message('WARN', 'No hay equipos para exportar');
    ob_clean();
    http_response_code(404);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'No hay equipos disponibles para exportar']);
    exit;
}

log_message('INFO', 'Total de equipos a exportar: ' . count($equipos));

// ============================================
// CREAR SPREADSHEET
// ============================================

log_message('INFO', 'Creando spreadsheet');

try {
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Equipos');
    
    log_message('DEBUG', 'Spreadsheet creado');
    
    // Headers
    $headers = [
        'ID',
        'Nombre del Equipo',
        'Modelo',
        'Marca',
        'Placa',
        'Código',
        'Ciudad',
        'Planta',
        'Línea de Producción',
        'Empresa',
        'Usuario Registro',
        'Estado ID'
    ];
    $sheet->fromArray($headers, NULL, 'A1');
    
    log_message('DEBUG', 'Headers agregados');
    
    // Estilos
    $headerStyle = [
        'font' => ['bold' => true, 'color' => ['rgb' => 'FFFFFF']],
        'fill' => [
            'fillType' => \PhpOffice\PhpSpreadsheet\Style\Fill::FILL_SOLID,
            'startColor' => ['rgb' => '4472C4']
        ],
        'alignment' => [
            'horizontal' => \PhpOffice\PhpSpreadsheet\Style\Alignment::HORIZONTAL_CENTER,
            'vertical' => \PhpOffice\PhpSpreadsheet\Style\Alignment::VERTICAL_CENTER
        ],
    ];
    $sheet->getStyle('A1:L1')->applyFromArray($headerStyle);
    
    log_message('DEBUG', 'Estilos de encabezado aplicados');
    
    // Datos
    $row = 2;
    foreach ($equipos as $equipo) {
        $sheet->setCellValue('A' . $row, $equipo['id'] ?? '');
        $sheet->setCellValue('B' . $row, $equipo['nombre'] ?? '');
        $sheet->setCellValue('C' . $row, $equipo['modelo'] ?? '');
        $sheet->setCellValue('D' . $row, $equipo['marca'] ?? '');
        $sheet->setCellValue('E' . $row, $equipo['placa'] ?? '');
        $sheet->setCellValue('F' . $row, $equipo['codigo'] ?? '');
        $sheet->setCellValue('G' . $row, $equipo['ciudad'] ?? '');
        $sheet->setCellValue('H' . $row, $equipo['planta'] ?? '');
        $sheet->setCellValue('I' . $row, $equipo['linea_prod'] ?? '');
        $sheet->setCellValue('J' . $row, $equipo['nombre_empresa'] ?? '');
        $sheet->setCellValue('K' . $row, $equipo['usuario_registro'] ?? '');
        $sheet->setCellValue('L' . $row, $equipo['estado_id'] ?? '');
        $row++;
    }
    
    log_message('DEBUG', 'Datos agregados al spreadsheet', ['filas' => (count($equipos) + 1)]);
    
    // Auto-size columnas
    foreach (range('A', 'L') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }
    
    log_message('DEBUG', 'Columnas auto-ajustadas');
    
    // Congelar encabezado
    $sheet->freezePane('A2');
    
    log_message('DEBUG', 'Encabezado congelado');
    
} catch (Exception $e) {
    log_message('ERROR', 'Error al crear spreadsheet', $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Error al generar archivo']);
    exit;
}

// ============================================
// PREPARAR DESCARGA
// ============================================

log_message('INFO', 'Preparando descarga del archivo');

$filename = 'equipos_' . date('Y-m-d_H-i-s') . '.xlsx';

log_message('DEBUG', 'Nombre del archivo', $filename);

// Limpiar buffer
if (ob_get_level()) {
    ob_end_clean();
    log_message('DEBUG', 'Output buffer limpiado');
}

// Headers de descarga
header('Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
header('Content-Disposition: attachment; filename="' . $filename . '"');
header('Cache-Control: max-age=0');
header('Pragma: public');
header('Expires: 0');

log_message('DEBUG', 'Headers de descarga establecidos');

// ============================================
// GENERAR Y ENVIAR ARCHIVO
// ============================================

log_message('INFO', 'Generando archivo Excel');

try {
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
    
    log_message('INFO', 'Archivo enviado exitosamente', [
        'filename' => $filename,
        'equipos' => count($equipos),
        'usuario' => $currentUser['usuario']
    ]);
} catch (Exception $e) {
    log_message('ERROR', 'Error al generar archivo', $e->getMessage());
}

// ============================================
// LIMPIEZA
// ============================================

if (isset($conn)) {
    $conn->close();
    log_message('DEBUG', 'Conexión a BD cerrada');
}

exit;

// ============================================
// MANEJADOR DE ERRORES GLOBAL
// ============================================

// Si llegamos aquí, algo salió muy mal
log_message('ERROR', 'Fin inesperado del script');
?>