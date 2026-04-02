<?php
// API_Infoapp/login/permissions/get_user_permissions.php
// Devuelve los permisos (módulo -> lista de acciones) de un usuario autenticado o específico

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_get_user_permissions.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
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
    log_debug("📋 REQUEST - GET USER PERMISSIONS");
    log_debug("👤 Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    // PASO 2: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 3: Log de acceso
    logAccess($currentUser, '/login/permissions/get_user_permissions.php', 'read_permissions');

    // PASO 4: Obtener user_id del query
    $userId = isset($_GET['user_id']) ? (int) $_GET['user_id'] : $currentUser['id'];

    log_debug("🔍 Consultando permisos para user_id: $userId");

    // Solo admin puede ver permisos de otros usuarios
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    if ($userId !== $currentUser['id'] && !$esAdmin) {
        log_debug("❌ Sin permisos para ver permisos de otros usuarios");
        sendJsonResponse(errorResponse('Solo administradores pueden ver permisos de otros usuarios'), 403);
    }

    if ($userId <= 0) {
        log_debug("❌ user_id inválido: $userId");
        sendJsonResponse(errorResponse('user_id inválido'), 400);
    }

    // PASO 5: Conexión a BD
    require '../../conexion.php';

    $sql = "SELECT module, action FROM user_permissions 
            WHERE user_id = ? AND allowed = 1 
            ORDER BY module, action";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        log_debug("❌ Error preparando query: " . $conn->error);
        throw new Exception('Error preparando consulta: ' . $conn->error);
    }

    $stmt->bind_param("i", $userId);

    if (!$stmt->execute()) {
        log_debug("❌ Error ejecutando query: " . $stmt->error);
        throw new Exception('Error al consultar permisos: ' . $stmt->error);
    }

    $result = $stmt->get_result();
    $rows = $result->fetch_all(MYSQLI_ASSOC);

    log_debug("✅ Query ejecutada, " . count($rows) . " permisos encontrados");

    // Agrupar por módulo
    $permisos = [];
    foreach ($rows as $row) {
        $modulo = $row['module'];
        $accion = $row['action'];

        if (!isset($permisos[$modulo])) {
            $permisos[$modulo] = [];
        }
        $permisos[$modulo][] = $accion;
    }

    log_debug("✅ Permisos agrupados por módulo");

    sendJsonResponse([
        'success' => true,
        'message' => 'Permisos consultados exitosamente',
        'user_id' => $userId,
        'data' => $permisos,
        'loaded_by' => $currentUser['usuario']
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