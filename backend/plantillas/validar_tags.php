<?php
// validar_tags.php - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_validar_tags.txt');

function log_debug($msg) {
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("🔴 ERROR FATAL: " . $error['message']);
        log_debug("📁 Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function($e) {
    log_debug("🔴 EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("📚 Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST - POST /plantillas/validar_tags");
log_debug("========================================");
log_debug("🌐 IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("🔗 URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("✅ auth_middleware cargado");
    
    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    
    logAccess($currentUser, '/plantillas/validar_tags.php', 'validate_tags');
    log_debug("✅ Acceso registrado");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    log_debug("📦 Requiriendo conexión...");
    require '../conexion.php';
    log_debug("✅ conexion.php cargado");

    $raw_input = file_get_contents('php://input');
    log_debug("📥 Raw input length: " . strlen($raw_input));
    
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        log_debug("❌ ERROR JSON: " . json_last_error_msg());
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    log_debug("✅ JSON decodificado correctamente");

    // ==================================================
    // VALIDAR PARÁMETRO contenido_html
    // ==================================================
    $contenido_html = $input['contenido_html'] ?? null;

    log_debug("📋 Parámetro recibido:");
    log_debug("   contenido_html length: " . strlen($contenido_html ?? ''));

    if (empty($contenido_html)) {
        log_debug("❌ contenido_html es requerido");
        throw new Exception('El parámetro contenido_html es requerido');
    }

    log_debug("✅ contenido_html válido");

    // ==================================================
    // 1. EXTRAER TODOS LOS TAGS DEL HTML
    // ==================================================
    log_debug("🔍 Extrayendo tags del HTML...");
    
    preg_match_all('/\{\{([^}]+)\}\}/', $contenido_html, $matches);
    $tags_encontrados = $matches[1];
    $tags_encontrados = array_unique($tags_encontrados);
    
    log_debug("✅ Tags encontrados: " . count($tags_encontrados));
    log_debug("   Tags: " . implode(', ', $tags_encontrados));

    // ==================================================
    // 2. OBTENER TODOS LOS TAGS VÁLIDOS DEL SISTEMA
    // ==================================================
    log_debug("📋 Obteniendo tags válidos del sistema...");
    
    $tags_validos = [];
    
    // ========== SECCIÓN: SERVICIOS ==========
    log_debug("📊 SECCIÓN: SERVICIOS");
    $cols_servicios = $conn->query("SHOW COLUMNS FROM servicios");
    if (!$cols_servicios) {
        throw new Exception("Error al obtener columnas de servicios: " . $conn->error);
    }
    $has_actividad_id = false;
    while ($col = $cols_servicios->fetch_assoc()) {
        if (!in_array($col['Field'], ['id', 'usuario_creador', 'usuario_ultima_actualizacion', 'id_equipo'])) {
            $tags_validos[] = $col['Field'];
            log_debug("   ➕ " . $col['Field']);
        }
        if ($col['Field'] === 'actividad_id') {
            $has_actividad_id = true;
        }
    }
    log_debug("   ✅ Total tags de servicios: " . $cols_servicios->num_rows);

    // Derivado: si existe actividad_id en servicios, permitir {{actividad_nombre}}
    if ($has_actividad_id) {
        $tags_validos[] = 'actividad_nombre';
        log_debug("   ➕ actividad_nombre (JOIN actividades_estandar.actividad)");
    }
    
    // ========== SECCIÓN: EQUIPOS ==========
    log_debug("📊 SECCIÓN: EQUIPOS");
    $cols_equipos = $conn->query("SHOW COLUMNS FROM equipos");
    if (!$cols_equipos) {
        throw new Exception("Error al obtener columnas de equipos: " . $conn->error);
    }
    while ($col = $cols_equipos->fetch_assoc()) {
        if (!in_array($col['Field'], ['id', 'usuario_registro', 'activo'])) {
            $tag_equipo = 'equipo_' . $col['Field'];
            $tags_validos[] = $tag_equipo;
            log_debug("   ➕ " . $tag_equipo);
        }
    }
    log_debug("   ✅ Total tags de equipos: " . $cols_equipos->num_rows);
    
    // ========== SECCIÓN: CLIENTE ==========
    log_debug("📊 SECCIÓN: CLIENTE");
    $tags_cliente = [
        'cliente_nombre',
        'cliente_ciudad',
        'cliente_planta',
        'cliente_codigo'
    ];
    $tags_validos = array_merge($tags_validos, $tags_cliente);
    foreach ($tags_cliente as $tag) {
        log_debug("   ➕ " . $tag);
    }
    log_debug("   ✅ Total tags de cliente: " . count($tags_cliente));
    
    // ========== SECCIÓN: USUARIOS ==========
    log_debug("📊 SECCIÓN: USUARIOS");
    $tags_usuarios = [
        'usuario_nombre_cliente',
        'usuario_nit',
        'usuario_correo',
        'usuario_nombre_user',
        'usuario_telefono'
    ];
    $tags_validos = array_merge($tags_validos, $tags_usuarios);
    foreach ($tags_usuarios as $tag) {
        log_debug("   ➕ " . $tag);
    }
    log_debug("   ✅ Total tags de usuarios: " . count($tags_usuarios));
    
    // ========== SECCIÓN: BRANDING ==========
    log_debug("📊 SECCIÓN: BRANDING");
    $tags_branding = [
        'branding_logo_url'
    ];
    $tags_validos = array_merge($tags_validos, $tags_branding);
    foreach ($tags_branding as $tag) {
        log_debug("   ➕ " . $tag);
    }
    log_debug("   ✅ Total tags de branding: " . count($tags_branding));
    
    // ========== SECCIÓN: CAMPOS ADICIONALES ==========
    log_debug("📊 SECCIÓN: CAMPOS ADICIONALES");
    $stmt_campos = $conn->prepare("
        SELECT nombre_campo 
        FROM campos_adicionales 
        WHERE modulo = 'servicios' 
        AND estado_mostrar > 0
    ");
    
    if (!$stmt_campos) {
        throw new Exception("Error preparando consulta de campos adicionales: " . $conn->error);
    }
    
    $stmt_campos->execute();
    $result_campos = $stmt_campos->get_result();
    $campos_count = 0;
    
    while ($campo = $result_campos->fetch_assoc()) {
        $slug = slugify($campo['nombre_campo']);
        $tag_campo = 'campo_' . $slug;
        $tags_validos[] = $tag_campo;
        log_debug("   ➕ " . $tag_campo . " (de: " . $campo['nombre_campo'] . ")");
        $campos_count++;
    }
    log_debug("   ✅ Total campos adicionales procesados: " . $campos_count);
    
    // ========== SECCIÓN: ESPECIALES (FOTOS) ==========
    log_debug("📊 SECCIÓN: ESPECIALES (FOTOS)");
    $tags_especiales = [
        'foto_antes',
        'foto_despues',
        'fotos_todas',
        'repuestos_lista'
    ];
    $tags_validos = array_merge($tags_validos, $tags_especiales);
    foreach ($tags_especiales as $tag) {
        log_debug("   ➕ " . $tag);
    }
    log_debug("   ✅ Total tags de fotos/repuestos: " . count($tags_especiales));
    
    // ========== SECCIÓN: FIRMAS (TABLA firmas) ==========
    log_debug("📊 SECCIÓN: FIRMAS");
    $tags_firmas = [
        // Usuario que entrega (desde tabla usuarios)
        'firma_usuario_id',
        'firma_usuario_nombre',
        'firma_usuario_imagen',
        'firma_nota_entrega',
        
        // Funcionario que recibe (desde tabla funcionarios)
        'firma_funcionario_id',
        'firma_funcionario_nombre',
        'firma_funcionario_imagen',
        'firma_nota_recepcion',
        
        // Fechas
        'firma_fecha_creacion',
        
        // Tags legacy (compatibilidad)
        'firma_tecnico',
        'firma_cliente'
    ];
    $tags_validos = array_merge($tags_validos, $tags_firmas);
    foreach ($tags_firmas as $tag) {
        log_debug("   ➕ " . $tag);
    }
    log_debug("   ✅ Total tags de firmas: " . count($tags_firmas));
    
    log_debug("========================================");
    log_debug("✅ TOTAL TAGS VÁLIDOS DEL SISTEMA: " . count($tags_validos));
    log_debug("========================================");

    // ==================================================
    // 3. VALIDAR CADA TAG ENCONTRADO
    // ==================================================
    log_debug("🔍 Validando tags encontrados...");
    
    $tags_validos_encontrados = [];
    $tags_invalidos = [];
    
    foreach ($tags_encontrados as $tag) {
        $tag_limpio = trim($tag);
        
        if (in_array($tag_limpio, $tags_validos)) {
            $tags_validos_encontrados[] = $tag_limpio;
            log_debug("   ✅ {{" . $tag_limpio . "}}");
        } else {
            $tags_invalidos[] = $tag_limpio;
            log_debug("   ❌ {{" . $tag_limpio . "}}");
        }
    }
    
    $es_valido = empty($tags_invalidos);
    
    log_debug("========================================");
    log_debug("📊 RESULTADO DE VALIDACIÓN:");
    log_debug("   Tags válidos encontrados: " . count($tags_validos_encontrados));
    log_debug("   Tags inválidos encontrados: " . count($tags_invalidos));
    log_debug("   Estado: " . ($es_valido ? '✅ VÁLIDO' : '❌ INVÁLIDO'));
    log_debug("========================================");

    // ==================================================
    // 4. RESPUESTA
    // ==================================================
    $response = [
        'success' => true,
        'message' => $es_valido 
            ? 'Todos los tags son válidos' 
            : 'Se encontraron tags inválidos',
        'data' => [
            'es_valido' => $es_valido,
            'total_tags_encontrados' => count($tags_encontrados),
            'tags_validos' => $tags_validos_encontrados,
            'tags_invalidos' => $tags_invalidos,
            'sugerencias' => $es_valido 
                ? [] 
                : array_map(function($tag_invalido) use ($tags_validos) {
                    return [
                        'tag_invalido' => $tag_invalido,
                        'sugerencias' => encontrarTagsSimilares($tag_invalido, $tags_validos)
                    ];
                }, $tags_invalidos)
        ]
    ];

    log_debug("📤 Enviando respuesta exitosa...");
    sendJsonResponse($response, 200);
    
    log_debug("✅ Respuesta enviada correctamente");

} catch (Exception $e) {
    log_debug("🔴🔴🔴 EXCEPTION CAPTURADA 🔴🔴🔴");
    log_debug("❌ Mensaje: " . $e->getMessage());
    log_debug("📁 Archivo: " . $e->getFile());
    log_debug("📍 Línea: " . $e->getLine());
    log_debug("📚 Stack trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_campos)) {
        $stmt_campos->close();
        log_debug("🔒 Sentencia preparada cerrada");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("🔒 Conexión con base de datos cerrada");
    }
    log_debug("========================================");
    log_debug("🏁 REQUEST FINALIZADA");
    log_debug("========================================\n");
}

// ==================================================
// FUNCIONES AUXILIARES
// ==================================================

/**
 * Convierte un texto a slug (minúsculas, reemplaza espacios y caracteres especiales)
 * 
 * @param string $text Texto a convertir
 * @return string Slug generado
 */
function slugify($text) {
    $text = iconv('UTF-8', 'ASCII//TRANSLIT', $text);
    $text = strtolower($text);
    $text = preg_replace('/[^a-z0-9]+/', '_', $text);
    $text = trim($text, '_');
    return $text;
}

/**
 * Encuentra tags similares al tag inválido usando similar_text()
 * 
 * @param string $tag_invalido Tag que no existe
 * @param array $tags_validos Array de tags válidos
 * @return array Array con sugerencias ordenadas por similitud
 */
function encontrarTagsSimilares($tag_invalido, $tags_validos) {
    $similares = [];
    
    foreach ($tags_validos as $tag_valido) {
        $similitud = similar_text(strtolower($tag_invalido), strtolower($tag_valido), $porcentaje);
        
        if ($porcentaje > 60) {
            $similares[] = [
                'tag' => $tag_valido,
                'similitud' => round($porcentaje, 2)
            ];
        }
    }
    
    // Ordenar por similitud descendente
    usort($similares, function($a, $b) {
        return $b['similitud'] <=> $a['similitud'];
    });
    
    // Retornar solo los 3 más similares
    return array_slice($similares, 0, 3);
}
?>