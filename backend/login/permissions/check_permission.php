<?php
// API_Infoapp/login/permissions/check_permission.php
// Valida si el usuario tiene permiso para un módulo+acción específico

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_check_permission.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

function is_valid_action(string $a): bool
{
    static $allowed = ['listar', 'crear', 'actualizar', 'eliminar', 'ver', 'exportar'];
    return in_array($a, $allowed, true);
}

require_once '../auth_middleware.php';

// Asegurar headers CORS desde el inicio
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
}

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    log_debug("========================================");
    log_debug("🔐 REQUEST - CHECK PERMISSION");
    log_debug("👤 Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    // PASO 2: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 3: Log de acceso
    logAccess($currentUser, '/login/permissions/check_permission.php', 'check_permission');

    // PASO 4: Leer parámetros (GET o POST JSON)
    $input = [];
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $input = json_decode(file_get_contents('php://input'), true) ?: [];
    } else {
        $input = $_GET;
    }

    $module = isset($input['module']) ? trim((string) $input['module']) : '';
    $action = isset($input['action']) ? trim((string) $input['action']) : '';
    $userId = isset($input['user_id']) ? (int) $input['user_id'] : $currentUser['id'];

    log_debug("📝 Parámetros - module: $module, action: $action, user_id: $userId");

    // Validaciones de entrada
    if ($module === '' || $action === '') {
        log_debug("❌ Parámetros vacíos");
        sendJsonResponse(errorResponse('Parámetros module y action son requeridos'), 400);
    }

    if (!is_valid_action($action)) {
        log_debug("❌ Acción inválida: $action");
        sendJsonResponse(errorResponse('Acción inválida'), 400);
    }

    if ($userId <= 0) {
        log_debug("❌ user_id inválido: $userId");
        sendJsonResponse(errorResponse('user_id inválido'), 400);
    }

    // Solo admin puede chequear permisos de otros usuarios
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    if ($userId !== $currentUser['id'] && !$esAdmin) {
        log_debug("❌ Sin permisos para consultar otros usuarios");
        sendJsonResponse(errorResponse('Solo administradores pueden consultar permisos de otros usuarios'), 403);
    }

    log_debug("✅ Validaciones OK");

    // PASO 5: Conexión a BD
    require '../../conexion.php';

    log_debug("🔍 Consultando permiso...");

    $sql = "SELECT 1 FROM user_permissions 
            WHERE user_id = ? AND module = ? AND action = ? AND allowed = 1 
            LIMIT 1";

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando query: " . $conn->error);
        throw new Exception('Error preparando consulta: ' . $conn->error);
    }

    $stmt->bind_param("iss", $userId, $module, $action);

    if (!$stmt->execute()) {
        log_debug("❌ Error ejecutando query: " . $stmt->error);
        throw new Exception('Error al consultar permiso: ' . $stmt->error);
    }

    $result = $stmt->get_result();
    $allowed = (bool) $result->fetch_column();

    log_debug("✅ Permiso consultado - Permitido: " . ($allowed ? 'SÍ' : 'NO'));

    sendJsonResponse([
        'success' => true,
        'user_id' => $userId,
        'module' => $module,
        'action' => $action,
        'allowed' => $allowed,
        'checked_by' => $currentUser['usuario']
    ], 200);

} catch (Exception $e) {
    log_debug("🔴 Exception: " . $e->getMessage());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
    log_debug("========================================\n");
}
?>