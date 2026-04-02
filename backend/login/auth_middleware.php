<?php
// auth_middleware.php
// Middleware para validar tokens JWT en endpoints protegidos

require_once __DIR__ . '/jwt_helper.php';

/**
 * Middleware principal de autenticación JWT
 * Valida el token y devuelve los datos del usuario autenticado
 * 
 * @param array $requiredRoles - Roles permitidos (opcional)
 * @return array - Datos del usuario autenticado
 * @throws Exception - Si la autenticación falla
 */
/**
 * Establece los headers CORS necesarios
 */
function setCORSHeaders()
{
    if (isset($_SERVER['HTTP_ORIGIN'])) {
        header("Access-Control-Allow-Origin: {$_SERVER['HTTP_ORIGIN']}");
        header('Access-Control-Allow-Credentials: true');
    } else {
        header("Access-Control-Allow-Origin: *");
    }

    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, User-ID");
    header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
    header("Content-Type: application/json; charset=utf-8");
}

/**
 * Middleware principal de autenticación JWT
 * Valida el token y devuelve los datos del usuario autenticado
 * 
 * @param array $requiredRoles - Roles permitidos (opcional)
 * @return array - Datos del usuario autenticado
 * @throws Exception - Si la autenticación falla
 */
function requireAuth($requiredRoles = null)
{
    $authStart = microtime(true);
    setCORSHeaders();

    // Manejar preflight OPTIONS
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }

    try {
        // Obtener token del header Authorization
        $token = getTokenFromHeader();

        if (!$token) {
            throw new Exception('Token de autenticación requerido');
        }

        // Validar el token
        $valStart = microtime(true);
        $validation = validateJWT($token);
        $GLOBALS['auth_timers']['jwt_validation'] = microtime(true) - $valStart;

        if (!$validation || !$validation['valid']) {
            $errorMessage = 'Token inválido';
            if (isset($validation['error'])) {
                $errorMessage = $validation['error'];
            }
            throw new Exception($errorMessage);
        }

        $userData = $validation['user_data'];

        // Verificar roles si se especificaron
        if ($requiredRoles !== null) {
            if (is_string($requiredRoles)) {
                $requiredRoles = [$requiredRoles];
            }

            if (!in_array($userData['rol'], $requiredRoles)) {
                throw new Exception('Permisos insuficientes para acceder a este recurso');
            }
        }

        // Verificar si el token está próximo a expirar
        $timeRemaining = $validation['time_remaining'];
        $shouldRefresh = ($timeRemaining < JWT_REFRESH_TIME);

        // Agregar información adicional
        $userData['token_info'] = [
            'expires_at' => $validation['expires_at'],
            'time_remaining' => $timeRemaining,
            'should_refresh' => $shouldRefresh
        ];

        return $userData;

    } catch (Exception $e) {
        // Respuesta de error de autenticación
        http_response_code(401);
        echo json_encode([
            'success' => false,
            'error' => 'Unauthorized',
            'message' => $e->getMessage(),
            'code' => 401
        ]);
        exit();
    }
}

/**
 * Middleware opcional - solo valida si hay token presente
 * Útil para endpoints que pueden funcionar con o sin autenticación
 * 
 * @return array|null - Datos del usuario si está autenticado, null si no
 */
function optionalAuth()
{
    setCORSHeaders();

    // Manejar preflight OPTIONS
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }

    try {
        $token = getTokenFromHeader();

        if (!$token) {
            return null;
        }

        $validation = validateJWT($token);

        if (!$validation || !$validation['valid']) {
            return null;
        }

        return $validation['user_data'];

    } catch (Exception $e) {
        return null;
    }
}

/**
 * Middleware para roles específicos
 * Shortcuts para roles comunes
 */
function requireAdmin()
{
    return requireAuth(['administrador', 'admin']);
}

function requireUser()
{
    return requireAuth(['usuario', 'user', 'administrador', 'admin']);
}

function requireModerator()
{
    return requireAuth(['moderador', 'administrador']);
}

/**
 * Verificar si el usuario actual puede realizar una acción
 * 
 * @param array $userData - Datos del usuario autenticado
 * @param string $action - Acción a verificar
 * @param array $resource - Recurso sobre el que se actúa (opcional)
 * @return bool
 */
function canPerformAction($userData, $action, $resource = null)
{
    $userRole = $userData['rol'];
    $userId = $userData['id'];

    switch ($action) {
        case 'view_users':
            return in_array($userRole, ['administrador', 'moderador']);

        case 'create_user':
        case 'delete_user':
            return $userRole === 'administrador';

        case 'edit_profile':
            // Puede editar su propio perfil o ser admin
            return ($resource && $resource['id'] == $userId) || $userRole === 'administrador';

        case 'view_reports':
            return in_array($userRole, ['administrador', 'moderador']);

        default:
            return false;
    }
}

/**
 * Verifica si el usuario tiene un permiso específico en la tabla user_permissions
 * 
 * @param mysqli $conn Conexión a la base de datos
 * @param int $userId ID del usuario
 * @param string $module Nombre del módulo
 * @param string $action Acción (listar, crear, actualizar, eliminar, ver, exportar)
 * @param string $userRole Rol del usuario (para bypass de admin)
 * @return bool
 */
function hasPermission($conn, $userId, $module, $action, $userRole = null)
{
    // Bypass para administradores
    $rolesAdmin = ['admin', 'administrador', 'gerente'];
    if ($userRole && in_array(strtolower($userRole), $rolesAdmin)) {
        return true;
    }

    $sql = "SELECT 1 FROM user_permissions 
            WHERE user_id = ? AND module = ? AND action = ? AND allowed = 1 
            LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt)
        return false;

    $stmt->bind_param("iss", $userId, $module, $action);
    $stmt->execute();
    $result = $stmt->get_result();
    $allowed = ($result->num_rows > 0);
    $stmt->close();

    return $allowed;
}

/**
 * Reclama un permiso y detiene la ejecución con 403 si no se tiene
 */
function requirePermission($conn, $userId, $module, $action, $userRole = null)
{
    if (!hasPermission($conn, $userId, $module, $action, $userRole)) {
        sendJsonResponse([
            'success' => false,
            'error' => 'Permission Denied',
            'message' => "No tienes permiso para realizar esta acción ($action en $module)",
            'code' => 403
        ], 403);
    }
}

/**
 * Obtener información del usuario autenticado actual
 * Para usar en cualquier parte del código después de requireAuth()
 * 
 * @return array
 */
function getCurrentUser()
{
    // Esta función debe llamarse después de requireAuth()
    // Los datos del usuario se pueden pasar como global o session
    global $currentUser;
    return $currentUser ?? null;
}

/**
 * Función de utilidad para enviar respuestas JSON consistentes
 * 
 * @param array $data - Datos a enviar
 * @param int $statusCode - Código de estado HTTP
 */
function sendJsonResponse($data, $statusCode = 200)
{
    http_response_code($statusCode);
    $json = json_encode($data);
    // ✅ FIX: Enviar Content-Length para evitar que el servidor se quede esperando
    header('Content-Length: ' . strlen($json));
    echo $json;
    exit();
}

/**
 * Función de utilidad para errores de autorización
 * 
 * @param string $message - Mensaje de error
 * @param int $code - Código de error
 */
function sendAuthError($message, $code = 403)
{
    sendJsonResponse([
        'success' => false,
        'error' => 'Access Denied',
        'message' => $message,
        'code' => $code
    ], $code);
}

/**
 * Middleware para logging de accesos (opcional)
 * 
 * @param array $userData - Datos del usuario
 * @param string $endpoint - Endpoint accedido
 * @param string $action - Acción realizada
 */
function logAccess($userData, $endpoint, $action = 'access')
{
    $logStart = microtime(true);
    $logEntry = [
        'timestamp' => date('Y-m-d H:i:s'),
        'user_id' => $userData['id'],
        'username' => $userData['usuario'],
        'role' => $userData['rol'],
        'endpoint' => $endpoint,
        'action' => $action,
        'ip' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        'user_agent' => $_SERVER['HTTP_USER_AGENT'] ?? 'unknown'
    ];

    // Aquí puedes implementar el guardado en base de datos o archivo de log
    error_log("AUTH_LOG: " . json_encode($logEntry));
    $GLOBALS['auth_timers']['log_access'] = microtime(true) - $logStart;
}

// Funciones de utilidad para respuestas comunes
function successResponse($data = null, $message = 'Operación exitosa')
{
    $response = ['success' => true, 'message' => $message];
    if ($data !== null) {
        $response['data'] = $data;
    }
    return $response;
}

function errorResponse($message, $code = 400)
{
    return [
        'success' => false,
        'error' => 'Bad Request',
        'message' => $message,
        'code' => $code
    ];
}

?>