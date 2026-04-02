<?php
// template_equipos.php
// Versión completa con JWT, logging robusto y CORS

// ============================================
// CONFIGURACIÓN DE LOGGING
// ============================================

define('LOG_DIR', __DIR__ . '/logs');
define('LOG_FILE', LOG_DIR . '/template_equipos_' . date('Y-m-d') . '.log');

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
header("Access-Control-Allow-Methods: GET, OPTIONS");
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

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    log_message('WARN', 'Método HTTP no permitido', $_SERVER['REQUEST_METHOD']);
    http_response_code(405);
    header('Content-Type: application/json');
    echo json_encode(['error' => 'Método no permitido, use GET']);
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
log_message('INFO', '=== NUEVA SOLICITUD DE DESCARGAR TEMPLATE ===');

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
use PhpOffice\PhpSpreadsheet\Style\Border;
use PhpOffice\PhpSpreadsheet\Style\Fill;
use PhpOffice\PhpSpreadsheet\Style\Alignment;

// ============================================
// GENERAR PLANTILLA
// ============================================

log_message('INFO', 'Iniciando generación de plantilla');

try {
    // Crear spreadsheet
    $spreadsheet = new Spreadsheet();
    $sheet = $spreadsheet->getActiveSheet();
    $sheet->setTitle('Equipos');
    
    log_message('DEBUG', 'Spreadsheet creado');
    
    // ============================================
    // ENCABEZADOS
    // ============================================
    
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
    log_message('DEBUG', 'Encabezados agregados');
    
    // ============================================
    // ESTILOS PARA ENCABEZADOS
    // ============================================
    
    $headerStyle = [
        'font' => [
            'bold' => true,
            'color' => ['rgb' => 'FFFFFF'],
            'size' => 12
        ],
        'fill' => [
            'fillType' => Fill::FILL_SOLID,
            'startColor' => ['rgb' => '4472C4']
        ],
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_CENTER,
            'vertical' => Alignment::VERTICAL_CENTER,
            'wrapText' => true
        ],
        'borders' => [
            'allBorders' => [
                'borderStyle' => Border::BORDER_THIN,
                'color' => ['rgb' => '000000']
            ]
        ]
    ];
    
    $sheet->getStyle('A1:L1')->applyFromArray($headerStyle);
    log_message('DEBUG', 'Estilos de encabezado aplicados');
    
    // ============================================
    // DATOS DE EJEMPLO
    // ============================================
    
    $ejemplos = [
        [
            '',
            'Excavadora Hidráulica',
            'CAT 320D',
            'Caterpillar',
            'ABC-123',
            'EQ001',
            'Barranquilla',
            'Planta Norte',
            'Construcción',
            'Argos',
            'sistema',
            '1'
        ],
        [
            '',
            'Camión Volquete',
            'HINO 500',
            'Hino',
            'DEF-456',
            'EQ002',
            'Soledad',
            'Planta Sur',
            'Transporte',
            'Cemex',
            'sistema',
            '2'
        ],
        [
            '',
            'Generador Eléctrico',
            'C175-16',
            'Caterpillar',
            'GEN-789',
            'EQ003',
            'Cartagena',
            'Planta Central',
            'Energía',
            'Enel',
            'sistema',
            '3'
        ],
    ];
    
    $row = 2;
    $dataStyle = [
        'alignment' => [
            'horizontal' => Alignment::HORIZONTAL_LEFT,
            'vertical' => Alignment::VERTICAL_TOP,
            'wrapText' => true
        ],
        'borders' => [
            'allBorders' => [
                'borderStyle' => Border::BORDER_THIN,
                'color' => ['rgb' => 'D3D3D3']
            ]
        ]
    ];
    
    foreach ($ejemplos as $ejemplo) {
        $sheet->fromArray($ejemplo, NULL, 'A' . $row);
        $sheet->getStyle('A' . $row . ':L' . $row)->applyFromArray($dataStyle);
        $row++;
    }
    
    log_message('DEBUG', 'Datos de ejemplo agregados', ['filas' => count($ejemplos)]);
    
    // ============================================
    // INSTRUCCIONES
    // ============================================
    
    $instructionRow = $row + 2;
    
    $sheet->setCellValue('A' . $instructionRow, 'INSTRUCCIONES:');
    $sheet->getStyle('A' . $instructionRow)->getFont()->setBold(true)->setSize(12);
    $instructionRow++;
    
    $instrucciones = [
        '• Deje la columna ID vacía para equipos nuevos',
        '• Los campos obligatorios son: Nombre, Placa y Empresa',
        '• La Placa debe ser única para cada equipo',
        '• Si la Placa ya existe, se actualizará el equipo',
        '• El campo Estado ID es opcional (usar solo si existe el estado en el sistema)',
        '• No modifique la estructura de las columnas'
    ];
    
    foreach ($instrucciones as $instruccion) {
        $sheet->setCellValue('A' . $instructionRow, $instruccion);
        $sheet->getStyle('A' . $instructionRow)->getFont()->setItalic(true)->setSize(10);
        $instructionRow++;
    }
    
    log_message('DEBUG', 'Instrucciones agregadas');
    
    // ============================================
    // AUTO-SIZE COLUMNAS
    // ============================================
    
    foreach (range('A', 'L') as $col) {
        $sheet->getColumnDimension($col)->setAutoSize(true);
    }
    
    log_message('DEBUG', 'Columnas auto-ajustadas');
    
    // ============================================
    // CONGELAR ENCABEZADO
    // ============================================
    
    $sheet->freezePane('A2');
    log_message('DEBUG', 'Encabezado congelado');
    
    // ============================================
    // PREPARAR DESCARGA
    // ============================================
    
    $filename = 'template_equipos_' . date('Y-m-d_H-i-s') . '.xlsx';
    log_message('INFO', 'Preparando descarga', ['filename' => $filename]);
    
    // Limpiar buffer
    if (ob_get_level()) {
        ob_end_clean();
    }
    
    // Headers para descarga
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
    
    $writer = new Xlsx($spreadsheet);
    $writer->save('php://output');
    
    log_message('INFO', 'Plantilla enviada exitosamente', [
        'filename' => $filename,
        'usuario' => $currentUser['usuario']
    ]);
    
} catch (Exception $e) {
    log_message('ERROR', 'Error al generar plantilla', $e->getMessage());
    
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'error' => 'Error al generar template',
        'details' => $e->getMessage()
    ]);
    exit;
}

// ============================================
// LIMPIEZA
// ============================================

log_message('DEBUG', 'Plantilla completada exitosamente');
exit;
?>