<?php
// Iniciar buffering inmediatamente para evitar que cualquier salida accidental corrompa el JSON/PDF
ob_start();

// ============================================
// HEADERS CORS - AGREGAR AL INICIO
// ============================================
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Responder a preflight OPTIONS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    ob_end_clean();
    http_response_code(200);
    exit();
}
// ============================================

// vista_previa_pdf.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_vista_previa_pdf.txt');

require_once __DIR__ . '/../core/PDFGeneratorFactory.php';
use Core\PDFGeneratorFactory;

// ==================================================
// UTILIDADES: Branding y CSS de respaldo para PDF
// ==================================================
function injectBrandingAndCss($html, $conn)
{
    // Obtener logo desde tabla branding
    $logoUrl = null;
    if ($conn) {
        $stmt = $conn->prepare("SELECT logo_url FROM branding LIMIT 1");
        if ($stmt) {
            $stmt->execute();
            $res = $stmt->get_result();
            if ($res && $res->num_rows > 0) {
                $row = $res->fetch_assoc();
                $logoUrl = $row['logo_url'] ?? null;
            }
            $stmt->close();
        }
    }

    // Intentar convertir a Data URI para evitar problemas de rutas/CORS
    $logoDataUri = null;
    if (!empty($logoUrl)) {
        $bytes = null;
        $mime = 'image/png';
        // Resolver ruta local si es relativa
        $apiRoot = dirname(__DIR__);
        $possibleLocal = $logoUrl;
        if (strpos($possibleLocal, 'http://') === 0 || strpos($possibleLocal, 'https://') === 0) {
            // URL absoluta
            try {
                $bytes = @file_get_contents($possibleLocal);
            } catch (Exception $e) {
                $bytes = null;
            }
        } else {
            // Ruta relativa dentro del backend
            $fullPath = $apiRoot . '/' . ltrim($possibleLocal, '/');
            if (is_file($fullPath)) {
                $bytes = @file_get_contents($fullPath);
                // Inferir MIME desde extensión
                $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
                if ($ext === 'jpg' || $ext === 'jpeg') {
                    $mime = 'image/jpeg';
                } elseif ($ext === 'gif') {
                    $mime = 'image/gif';
                } elseif ($ext === 'svg') {
                    $mime = 'image/svg+xml';
                } else {
                    $mime = 'image/png';
                }
            }
        }

        if ($bytes) {
            $logoDataUri = 'data:' . $mime . ';base64,' . base64_encode($bytes);
        }
    }

    // Reemplazar tags de branding
    if ($logoDataUri) {
        // Para plantillas que usan <img src="{{branding_logo_url}}">
        $html = str_replace('{{branding_logo_url}}', $logoDataUri, $html);
        // Compatibilidad: {{logo_empresa}} como bloque de imagen directa
        if (strpos($html, '{{logo_empresa}}') !== false) {
            $html = str_replace('{{logo_empresa}}', '<img src="' . $logoDataUri . '" style="max-height:100px;"/>', $html);
        }
    } elseif (!empty($logoUrl)) {
        // Si no se pudo convertir a data URI, usar la URL original
        $html = str_replace('{{branding_logo_url}}', $logoUrl, $html);
        if (strpos($html, '{{logo_empresa}}') !== false) {
            $html = str_replace('{{logo_empresa}}', '<img src="' . $logoUrl . '" style="max-height:100px;"/>', $html);
        }
    }

    // CSS de respaldo para header (evitar flex no soportado por TCPDF)
    $fallbackCss = '<style>
        header { overflow: hidden; border-bottom: 4px solid #0056b3; margin-bottom: 20px; padding: 10px 0; }
        .company-info { float: left; width: 75%; text-align: left; padding-right: 20px; }
        .header-logo { float: right; width: 100px; height: auto; object-fit: contain; }
    </style>';

    if (stripos($html, '</head>') !== false) {
        $html = preg_replace('/<\/head>/i', $fallbackCss . '</head>', $html, 1);
    } else {
        $html = $fallbackCss . $html;
    }

    return $html;
}

// ==================================================
// Normalización de encabezado para TCPDF
// Reemplaza <header> ... </header> por una tabla de 2 columnas
// ==================================================
function normalizeHeaderForPdf($html)
{
    // Extraer contenido de company-info
    $companyHtml = '';
    if (preg_match('/<div[^>]*class="[^"]*company-info[^"]*"[^>]*>(.*?)<\/div>/is', $html, $m)) {
        $companyHtml = $m[1];
    }
    // Extraer src del logo
    $logoSrc = null;
    if (preg_match('/<img[^>]*class="[^"]*header-logo[^"]*"[^>]*src="([^"]+)"/i', $html, $m)) {
        $logoSrc = $m[1];
    }

    $tableHeader = '<table style="width:100%; border-bottom:4px solid #0056b3; margin-bottom:15px;">
        <tr>
            <td style="width:75%; text-align:left; vertical-align:middle; padding-right:20px;">' . $companyHtml . '</td>
            <td style="width:25%; text-align:right; vertical-align:middle;">' . (!empty($logoSrc) ? '<img src="' . htmlspecialchars($logoSrc) . '" style="max-height:100px; width:auto;" />' : '') . '</td>
        </tr>
    </table>';

    // Reemplazar el bloque header por la tabla
    $html = preg_replace('/<header[^>]*>.*?<\/header>/is', $tableHeader, $html, 1);
    return $html;
}

// ==================================================
// Branding sin alterar CSS (para vista previa)
// ==================================================
function injectBrandingNoCss($html, $conn)
{
    // Igual que injectBrandingAndCss pero sin inyectar estilos ni tocar header
    $logoUrl = null;
    if ($conn) {
        $stmt = $conn->prepare("SELECT logo_url FROM branding LIMIT 1");
        if ($stmt) {
            $stmt->execute();
            $res = $stmt->get_result();
            if ($res && $res->num_rows > 0) {
                $row = $res->fetch_assoc();
                $logoUrl = $row['logo_url'] ?? null;
            }
            $stmt->close();
        }
    }
    $logoDataUri = null;
    if (!empty($logoUrl)) {
        $bytes = null;
        $mime = 'image/png';
        $apiRoot = dirname(__DIR__);
        if (strpos($logoUrl, 'http://') === 0 || strpos($logoUrl, 'https://') === 0) {
            try {
                $bytes = @file_get_contents($logoUrl);
            } catch (Exception $e) {
                $bytes = null;
            }
        } else {
            $fullPath = $apiRoot . '/' . ltrim($logoUrl, '/');
            if (is_file($fullPath)) {
                $bytes = @file_get_contents($fullPath);
                $ext = strtolower(pathinfo($fullPath, PATHINFO_EXTENSION));
                if ($ext === 'jpg' || $ext === 'jpeg') {
                    $mime = 'image/jpeg';
                } elseif ($ext === 'gif') {
                    $mime = 'image/gif';
                } elseif ($ext === 'svg') {
                    $mime = 'image/svg+xml';
                } else {
                    $mime = 'image/png';
                }
            }
        }
        if ($bytes) {
            $logoDataUri = 'data:' . $mime . ';base64,' . base64_encode($bytes);
        }
    }
    if ($logoDataUri) {
        $html = str_replace('{{branding_logo_url}}', $logoDataUri, $html);
        if (strpos($html, '{{logo_empresa}}') !== false) {
            $html = str_replace('{{logo_empresa}}', '<img src="' . $logoDataUri . '" style="max-height:100px;"/>', $html);
        }
    } elseif (!empty($logoUrl)) {
        $html = str_replace('{{branding_logo_url}}', $logoUrl, $html);
        if (strpos($html, '{{logo_empresa}}') !== false) {
            $html = str_replace('{{logo_empresa}}', '<img src="' . $logoUrl . '" style="max-height:100px;"/>', $html);
        }
    }
    return $html;
}

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function () {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("🔴 ERROR FATAL: " . $error['message']);
        log_debug("📁 Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function ($e) {
    log_debug("🔴 EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("📚 Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST - POST /informes/vista_previa_pdf");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
// La cabecera Content-Type se establecerá justo antes de enviar la respuesta final
// para evitar que auth_middleware envíe application/json prematuramente si hay errores.
require_once __DIR__ . '/../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/informes/vista_previa_pdf.php', 'preview_pdf');
    log_debug("✅ Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("📦 Requiriendo conexión y librerías...");
    require __DIR__ . '/../conexion.php';
    require __DIR__ . '/obtener_datos_servicio.php';
    require __DIR__ . '/procesar_tags.php';
    log_debug("✅ Dependencias cargadas");

    $raw_input = file_get_contents('php://input');
    log_debug("📥 Raw input length: " . strlen($raw_input));

    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        log_debug("❌ ERROR JSON: " . json_last_error_msg());
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    log_debug("✅ JSON decodificado correctamente");

    // ==================================================
    // MODO CONTENIDO_HTML: PREVIEW O PDF SEGÚN FLAG
    // ==================================================
    $contenido_html = isset($input['contenido_html']) ? trim($input['contenido_html']) : null;
    if (!empty($contenido_html)) {
        log_debug("📝 contenido_html presente (len=" . strlen($contenido_html) . ")");

        // Determinar si se solicitó generar PDF explícitamente
        $generar_pdf = false;
        foreach (['generar_pdf', 'descargar_pdf', 'solo_pdf'] as $flag) {
            if (isset($input[$flag])) {
                $val = $input[$flag];
                $generar_pdf = ($val === true || $val === 1 || $val === '1' || $val === 'true');
                if ($generar_pdf) {
                    break;
                }
            }
        }

        // Resolver servicio_id a partir de o_servicio si no viene
        $servicio_id = isset($input['servicio_id']) ? (int) $input['servicio_id'] : null;
        $o_servicio = isset($input['o_servicio']) ? trim($input['o_servicio']) : null;

        if (!$servicio_id && $o_servicio) {
            log_debug("🔍 Buscando servicio por o_servicio (HTML directo): $o_servicio");
            $stmt_servicio = $conn->prepare("SELECT id, o_servicio FROM servicios WHERE o_servicio = ? LIMIT 1");
            $stmt_servicio->bind_param("s", $o_servicio);
            $stmt_servicio->execute();
            $result_servicio = $stmt_servicio->get_result();
            if ($result_servicio->num_rows > 0) {
                $servicio = $result_servicio->fetch_assoc();
                $servicio_id = (int) $servicio['id'];
                $o_servicio = $servicio['o_servicio'];
                log_debug("✅ Servicio encontrado: ID $servicio_id");
            } else {
                log_debug("❌ No se encontró servicio con o_servicio: $o_servicio");
                throw new Exception("No se encontró ningún servicio con orden: $o_servicio");
            }
            $stmt_servicio->close();
        }

        if (!$servicio_id) {
            log_debug("❌ servicio_id requerido para procesar tags en contenido_html");
            throw new Exception('Debe proporcionar servicio_id u o_servicio para procesar contenido_html');
        }

        // Obtener datos del servicio
        $datos_servicio = obtenerDatosServicio($servicio_id, $conn);
        if (!$datos_servicio) {
            log_debug("❌ Servicio no encontrado");
            throw new Exception("Servicio no encontrado con ID: $servicio_id");
        }
        log_debug("✅ Datos del servicio obtenidos correctamente (HTML directo)");

        // Procesar tags en el contenido_html recibido
        log_debug("🔄 Procesando tags en contenido_html recibido...");
        $html_original = $contenido_html;
        $html_procesado = procesarTags($contenido_html, $datos_servicio);
        // Inyectar branding y CSS de respaldo para compatibilidad
        // Vista previa: respetar totalmente el CSS de la plantilla
        $html_procesado = injectBrandingNoCss($html_procesado, $conn);
        // Para PDF (más abajo) haremos compatibilidad específica, no aquí
        log_debug("✅ Tags procesados (HTML directo)");

        if ($generar_pdf) {
            // Generar PDF y devolver ruta pública
            // Limpiar cualquier salida accidental previa (warnings de librerías, etc.)
            if (ob_get_length())
                ob_clean();
            require_once __DIR__ . '/../vendor/autoload.php';

            $apiRoot = dirname(__DIR__);
            $destDir = $apiRoot . '/uploads/informes';
            if (!is_dir($destDir)) {
                if (!mkdir($destDir, 0775, true) && !is_dir($destDir)) {
                    log_debug("❌ No se pudo crear el directorio: $destDir");
                    throw new Exception('No se pudo preparar el directorio de informes');
                }
                log_debug("📁 Directorio creado: $destDir");
            }

            $ordenPayload = $o_servicio ?: 'preview';
            $filename = 'informe_preview_' . ($ordenPayload ?: 'preview') . '_' . date('YmdHis') . '.pdf';
            $fullPath = $destDir . '/' . $filename;

            // Detección de motor para vista previa
            $engine = 'legacy';
            if (preg_match('/display\s*:\s*(flex|grid)|gap\s*:|aspect-ratio/i', $html_procesado)) {
                $engine = 'modern';
            }

            $factory = new PDFGeneratorFactory($engine);
            $factory->generate($html_procesado, '', $fullPath, 'F');
            log_debug("✅ PDF generado con motor $engine en: $fullPath");

            // Asegurar que el buffer esté limpio antes de enviar JSON
            if (ob_get_length()) {
                $extra_output = ob_get_clean();
                if (!empty($extra_output)) {
                    log_debug("⚠️ Salida accidental detectada y limpiada: " . substr($extra_output, 0, 500));
                }
            }

            $ruta_publica = 'uploads/informes/' . $filename;
            $response = [
                'success' => true,
                'message' => 'PDF generado exitosamente desde HTML',
                'data' => [
                    'servicio_id' => $servicio_id,
                    'o_servicio' => $ordenPayload,
                    'ruta_publica' => $ruta_publica,
                    'archivo' => [
                        'nombre' => $filename,
                        'ruta_publica' => $ruta_publica,
                    ],
                ],
            ];
            sendJsonResponse($response, 200);
            log_debug("📤 Respuesta enviada (HTML directo) con ruta_publica del PDF");
            return;
        }

        // Modo vista previa: devolver html_procesado
        $response = [
            'success' => true,
            'message' => 'Vista previa generada exitosamente (HTML directo)',
            'data' => [
                'servicio_id' => $servicio_id,
                'o_servicio' => $o_servicio,
                'html_original' => $html_original,
                'html_procesado' => $html_procesado,
            ],
        ];
        if (ob_get_length()) {
            $extra_output = ob_get_clean();
            if (!empty($extra_output)) {
                log_debug("⚠️ Salida accidental detectada y limpiada (Preview): " . substr($extra_output, 0, 500));
            }
        }
        sendJsonResponse($response, 200);
        log_debug("📤 Respuesta enviada (HTML directo) con html_procesado");
        return;
    }

    // ==================================================
// VALIDAR PARÁMETROS servicio_id O o_servicio
// ==================================================
    $servicio_id = isset($input['servicio_id']) ? (int) $input['servicio_id'] : null;
    $o_servicio = isset($input['o_servicio']) ? trim($input['o_servicio']) : null;

    log_debug("📋 Parámetros recibidos:");
    log_debug("   servicio_id: " . ($servicio_id ?? 'NULL'));
    log_debug("   o_servicio: " . ($o_servicio ?? 'NULL'));

    // Validar que al menos uno esté presente
    if (!$servicio_id && !$o_servicio) {
        log_debug("❌ Se requiere servicio_id o o_servicio");
        throw new Exception('Debe proporcionar servicio_id o o_servicio');
    }

    // Si viene o_servicio, buscar el servicio_id
    if ($o_servicio && !$servicio_id) {
        log_debug("🔍 Buscando servicio por o_servicio: $o_servicio");

        $stmt_servicio = $conn->prepare("
        SELECT id 
        FROM servicios 
        WHERE o_servicio = ? 
        LIMIT 1
    ");
        $stmt_servicio->bind_param("s", $o_servicio);
        $stmt_servicio->execute();
        $result_servicio = $stmt_servicio->get_result();

        if ($result_servicio->num_rows > 0) {
            $servicio = $result_servicio->fetch_assoc();
            $servicio_id = (int) $servicio['id'];
            log_debug("✅ Servicio encontrado: ID $servicio_id");
        } else {
            log_debug("❌ No se encontró servicio con o_servicio: $o_servicio");
            throw new Exception("No se encontró ningún servicio con orden: $o_servicio");
        }

        $stmt_servicio->close();
    }

    log_debug("✅ servicio_id final: $servicio_id");

    // Continuar con el flujo norma
    // ==================================================
    // 1. OBTENER DATOS DEL SERVICIO
    // ==================================================
    log_debug("📋 Obteniendo datos completos del servicio...");

    $datos_servicio = obtenerDatosServicio($servicio_id, $conn);

    if (!$datos_servicio) {
        log_debug("❌ Servicio no encontrado");
        throw new Exception("Servicio no encontrado con ID: $servicio_id");
    }

    log_debug("✅ Datos del servicio obtenidos correctamente");

    // ==================================================
    // 2. OBTENER PLANTILLA CORRESPONDIENTE
    // ==================================================
    $plantilla_id = isset($input['plantilla_id']) ? (int) $input['plantilla_id'] : null;
    $cliente_id = $datos_servicio['cliente']['id'] ?? null;

    // Si no tenemos ID de cliente (porque no se encontró en la tabla clientes),
    // registramos advertencia pero intentaremos buscar plantilla general.
    if (!$cliente_id && !$plantilla_id) {
        log_debug("⚠️ No se identificó ID de cliente ni plantilla_id. Se buscará solo plantilla general.");
    } else if ($plantilla_id) {
        log_debug("🔍 Usando plantilla_id explícita: $plantilla_id");
    } else {
        log_debug("🔍 Cliente identificado: ID $cliente_id");
    }

    log_debug("📋 Buscando plantilla...");

    $plantilla = null;
    $tipo_plantilla = null;

    // 0. Prioridad máxima: plantilla_id explícita
    if ($plantilla_id) {
        $stmt_plantilla = $conn->prepare("SELECT * FROM plantillas WHERE id = ? LIMIT 1");
        $stmt_plantilla->bind_param("i", $plantilla_id);
        $stmt_plantilla->execute();
        $result_plantilla = $stmt_plantilla->get_result();

        if ($result_plantilla->num_rows > 0) {
            $plantilla = $result_plantilla->fetch_assoc();
            $tipo_plantilla = 'explicita';
            log_debug("✅ Plantilla explícita encontrada por ID: " . $plantilla['nombre']);
        } else {
            log_debug("⚠️ plantilla_id $plantilla_id no encontrada. Fallback a detección automática.");
        }
        $stmt_plantilla->close();
    }

    // 1. Intentar buscar plantilla específica si tenemos cliente_id y no se encontró por ID
    if (!$plantilla && $cliente_id) {
        $stmt_plantilla = $conn->prepare("
            SELECT * FROM plantillas 
            WHERE cliente_id = ? 
            LIMIT 1
        ");
        $stmt_plantilla->bind_param("i", $cliente_id);
        $stmt_plantilla->execute();
        $result_plantilla = $stmt_plantilla->get_result();

        if ($result_plantilla->num_rows > 0) {
            $plantilla = $result_plantilla->fetch_assoc();
            $tipo_plantilla = 'especifica';
            log_debug("✅ Plantilla específica encontrada: " . $plantilla['nombre']);
        } else {
            log_debug("⚠️ El cliente ID $cliente_id no tiene plantilla específica.");
        }
        $stmt_plantilla->close();
    }

    // 2. Si no hay plantilla específica (o no hay cliente_id), buscar general
    if (!$plantilla) {
        log_debug("📋 Buscando plantilla general...");
        $stmt_general = $conn->prepare("
            SELECT * FROM plantillas 
            WHERE es_general = 1 
            ORDER BY fecha_creacion DESC 
            LIMIT 1
        ");
        $stmt_general->execute();
        $result_general = $stmt_general->get_result();

        if ($result_general->num_rows > 0) {
            $plantilla = $result_general->fetch_assoc();
            $tipo_plantilla = 'general';
            log_debug("✅ Plantilla general encontrada: " . $plantilla['nombre']);
        }
        $stmt_general->close();
    }

    if (!$plantilla) {
        log_debug("❌ No hay plantillas disponibles");
        throw new Exception("No hay plantillas disponibles. Debe crear al menos una plantilla general o una específica para este cliente.");
    }

    // ==================================================
    // 3. PROCESAR TAGS EN EL HTML
    // ==================================================
    log_debug("🔄 Procesando tags en el HTML...");

    $html_original = $plantilla['contenido_html'];
    $html_procesado = procesarTags($html_original, $datos_servicio);
    // Inyectar branding y CSS de respaldo para compatibilidad
    // Vista previa: respetar totalmente el CSS de la plantilla
    $html_procesado = injectBrandingNoCss($html_procesado, $conn);

    log_debug("✅ Tags procesados correctamente");
    log_debug("📊 HTML original length: " . strlen($html_original));
    log_debug("📊 HTML procesado length: " . strlen($html_procesado));

    // ==================================================
    // 4. RETORNAR HTML PROCESADO (NO GENERAR PDF)
    // ==================================================
    log_debug("📤 Retornando HTML procesado...");

    $response = [
        'success' => true,
        'message' => 'Vista previa generada exitosamente',
        'data' => [
            'servicio_id' => $servicio_id,
            'o_servicio' => $datos_servicio['servicio']['o_servicio'],
            'plantilla_id' => (int) $plantilla['id'],
            'plantilla_nombre' => $plantilla['nombre'],
            'tipo_plantilla' => $tipo_plantilla,
            'html_original' => $html_original,
            'html_procesado' => $html_procesado,
            'cliente' => [
                'id' => $cliente_id,
                'nombre' => $datos_servicio['cliente']['nombre']
            ]
        ]
    ];

    log_debug("📤 Enviando respuesta JSON con HTML procesado...");
    sendJsonResponse($response, 200);

    log_debug("✅ Respuesta enviada exitosamente");

} catch (Exception $e) {
    log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
    log_debug("❌ Mensaje: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile());
    log_debug("📍 Línea: " . $e->getLine());
    log_debug("📚 Trace: " . $e->getTraceAsString());
    if (ob_get_length()) {
        $extra_output = ob_get_clean();
        if (!empty($extra_output)) {
            log_debug("⚠️ Salida accidental detectada y limpiada (Error): " . substr($extra_output, 0, 500));
        }
    }
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_plantilla)) {
        $stmt_plantilla->close();
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}
?>