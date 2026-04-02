<?php
// Log inmediato desde el primer byte
define('DEBUG_LOG', __DIR__ . '/debug_generar_pdf.txt');
file_put_contents(DEBUG_LOG, "\n" . date('Y-m-d H:i:s') . " 🆕 INICIANDO REFACTORED\n", FILE_APPEND);

// Iniciar buffering para evitar que errores o advertencias de librerías corrompan la salida
ob_start();

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

use Core\PDFGeneratorFactory;

function log_debug($msg)
{
    file_put_contents(DEBUG_LOG, date('Y-m-d H:i:s') . " $msg\n", FILE_APPEND);
}

log_debug("✅ Constantes definidas");

try {
    log_debug("📦 Require autoload y dependencias");
    require_once __DIR__ . '/../vendor/autoload.php';
    require_once __DIR__ . '/../login/auth_middleware.php';
    require_once __DIR__ . '/../conexion.php';
    require_once __DIR__ . '/obtener_datos_servicio.php';
    require_once __DIR__ . '/procesar_tags.php';
    require_once __DIR__ . '/../core/PDFGeneratorFactory.php';

    $currentUser = requireAuth();
    log_debug("👤 Usuario: " . $currentUser['usuario']);
    logAccess($currentUser, '/informes/generar_pdf.php', 'generate_pdf');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        throw new Exception('POST requerido');
    }

    $input = json_decode(file_get_contents('php://input'), true);
    if (!$input && !empty($_POST)) {
        $input = $_POST;
    }

    if (!$input) {
        throw new Exception('JSON inválido o datos POST faltantes');
    }

    $servicio_id = (int) ($input['servicio_id'] ?? 0);
    $o_servicio = isset($input['o_servicio']) ? trim($input['o_servicio']) : null;

    if (!$servicio_id && $o_servicio) {
        log_debug("🔍 Buscando servicio por o_servicio: $o_servicio");
        $stmt_servicio = $conn->prepare("SELECT id FROM servicios WHERE o_servicio = ? LIMIT 1");
        $stmt_servicio->bind_param("s", $o_servicio);
        $stmt_servicio->execute();
        $result_servicio = $stmt_servicio->get_result();
        if ($result_servicio->num_rows > 0) {
            $servicio = $result_servicio->fetch_assoc();
            $servicio_id = (int) $servicio['id'];
        }
        $stmt_servicio->close();
    }

    if (!$servicio_id) {
        throw new Exception('servicio_id requerido');
    }

    $datos_servicio = obtenerDatosServicio($servicio_id, $conn);
    if (!$datos_servicio)
        throw new Exception("Servicio no encontrado");

    // Obtener plantilla
    $cliente_id = $datos_servicio['cliente']['id'] ?? null;
    $plantilla = null;

    $stmt = $conn->prepare("SELECT * FROM plantillas WHERE cliente_id = ? OR (es_general = 1) ORDER BY (cliente_id = ?) DESC, fecha_creacion DESC LIMIT 1");
    $stmt->bind_param("ii", $cliente_id, $cliente_id);
    $stmt->execute();
    $result = $stmt->get_result();
    if ($result->num_rows > 0) {
        $plantilla = $result->fetch_assoc();
    }
    $stmt->close();

    if (!$plantilla)
        throw new Exception("Sin plantilla disponible");

    $html = $plantilla['contenido_html'];
    $html = str_replace(['&lt;', '&gt;', '&amp;', '&quot;', '&apos;'], ['<', '>', '&', '"', "'"], $html);
    $html = procesarTags($html, $datos_servicio);

    // Detección de motor
    $requestedEngine = strtolower($input['engine'] ?? 'legacy');
    // Si no se especifica, autodetección simple por CSS moderno
    if (!isset($input['engine'])) {
        if (preg_match('/display\s*:\s*(flex|grid)|gap\s*:|aspect-ratio/i', $html)) {
            $requestedEngine = 'modern';
            log_debug("⚠️  CSS moderno detectado, cambiando a motor 'modern'");
        }
    }

    log_debug("🚀 Iniciando generación con motor: $requestedEngine");

    // Limpiar cualquier salida accidental previa (warnings, etc.) para no corromper el PDF
    if (ob_get_length())
        ob_clean();

    $factory = new PDFGeneratorFactory($requestedEngine);

    $filename = 'informe_' . ($datos_servicio['servicio']['o_servicio'] ?? 'servicio') . '_' . date('YmdHis') . '.pdf';
    $dest = (isset($input['inline']) && $input['inline']) ? 'I' : 'I'; // El usuario pidió Inline siempre para Flutter

    $factory->generate($html, '', $filename, $dest);

    log_debug("✅ PDF Generado exitosamente");

} catch (Exception $e) {
    log_debug("❌ ERROR: " . $e->getMessage());
    // Limpiar buffer antes de enviar error JSON
    if (ob_get_length())
        ob_clean();
    header('Content-Type: application/json');
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
    http_response_code(500);
} finally {
    if (isset($conn))
        $conn->close();
    log_debug("🏁 FIN\n");
}
