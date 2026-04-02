<?php
// jwt_helper.php
// Funciones auxiliares para manejar JSON Web Tokens (JWT) - Versión corregida

// Incluir las dependencias necesarias
require_once __DIR__ . '/jwt_config.php';
require_once __DIR__ . '/jwt/JWT.php';
require_once __DIR__ . '/jwt/Key.php';
require_once __DIR__ . '/jwt/SignatureInvalidException.php';
require_once __DIR__ . '/jwt/BeforeValidException.php';
require_once __DIR__ . '/jwt/ExpiredException.php';

/**
 * GENERAR TOKEN JWT
 */
function generateJWT($userData)
{
    try {
        // Tiempo actual
        $now = time();

        // Crear el payload
        $payload = [
            'iss' => JWT_ISSUER,
            'aud' => JWT_AUDIENCE,
            'iat' => $now,
            'nbf' => $now,
            'exp' => $now + JWT_EXPIRATION_TIME,
            'user_data' => [
                'id' => $userData['id'],
                'usuario' => $userData['usuario'],
                'rol' => $userData['rol'],
                'estado' => $userData['estado'] ?? 'activo',
                'nombre_completo' => $userData['nombre_completo'] ?? null,
                'correo' => $userData['correo'] ?? null,
                'nit' => $userData['nit'] ?? null,
                'funcionario_id' => $userData['funcionario_id'] ?? null,
                'cliente_id' => $userData['cliente_id'] ?? null,
            ],
            'session_id' => uniqid('sess_', true),
            'ip_address' => $_SERVER['REMOTE_ADDR'] ?? 'unknown',
        ];

        // Generar el token usando nuestra clase JWT simplificada
        $jwt = JWT::encode($payload, JWT_SECRET_KEY, JWT_ALGORITHM);

        return $jwt;

    } catch (Exception $e) {
        error_log("Error generando JWT: " . $e->getMessage());
        return false;
    }
}

/**
 * VALIDAR TOKEN JWT
 */
function validateJWT($token)
{
    try {
        // Limpiar el token
        $token = str_replace('Bearer ', '', $token);
        $token = trim($token);

        if (empty($token)) {
            return false;
        }

        // Decodificar y validar el token usando nuestra clase JWT simplificada
        $decoded = JWT::decode($token, JWT_SECRET_KEY, [JWT_ALGORITHM]);

        // Convertir el objeto a array
        $payload = (array) $decoded;
        $user_data = (array) $payload['user_data'];

        // Validaciones adicionales
        if (!isset($payload['iss']) || $payload['iss'] !== JWT_ISSUER) {
            throw new Exception("Emisor inválido");
        }

        if (!isset($payload['aud']) || $payload['aud'] !== JWT_AUDIENCE) {
            throw new Exception("Audiencia inválida");
        }

        return [
            'valid' => true,
            'user_data' => $user_data,
            'payload' => $payload,
            'expires_at' => $payload['exp'],
            'time_remaining' => $payload['exp'] - time()
        ];

    } catch (ExpiredException $e) {
        return ['valid' => false, 'error' => 'Token expirado', 'code' => 'EXPIRED'];

    } catch (SignatureInvalidException $e) {
        return ['valid' => false, 'error' => 'Token inválido', 'code' => 'INVALID_SIGNATURE'];

    } catch (BeforeValidException $e) {
        return ['valid' => false, 'error' => 'Token no válido aún', 'code' => 'NOT_YET_VALID'];

    } catch (Exception $e) {
        return ['valid' => false, 'error' => 'Token inválido', 'code' => 'INVALID'];
    }
}

/**
 * EXTRAER TOKEN DEL HEADER
 */
function getTokenFromHeader()
{
    // Función auxiliar para obtener headers
    if (function_exists('getallheaders')) {
        $headers = getallheaders();
    } else {
        $headers = [];
        foreach ($_SERVER as $key => $value) {
            if (substr($key, 0, 5) == 'HTTP_') {
                $headers[str_replace(' ', '-', ucwords(str_replace('_', ' ', strtolower(substr($key, 5)))))] = $value;
            }
        }
    }

    // Buscar el header Authorization
    foreach ($headers as $name => $value) {
        if (strtolower($name) === 'authorization') {
            if (strpos($value, 'Bearer ') === 0) {
                return substr($value, 7);
            }
            return $value;
        }
    }

    // Fallback
    if (isset($_SERVER['HTTP_AUTHORIZATION'])) {
        $auth = $_SERVER['HTTP_AUTHORIZATION'];
        if (strpos($auth, 'Bearer ') === 0) {
            return substr($auth, 7);
        }
        return $auth;
    }

    // Fallback para Apache/ModRewrite
    if (isset($_SERVER['REDIRECT_HTTP_AUTHORIZATION'])) {
        $auth = $_SERVER['REDIRECT_HTTP_AUTHORIZATION'];
        if (strpos($auth, 'Bearer ') === 0) {
            return substr($auth, 7);
        }
        return $auth;
    }

    // Fallback 2: Parámetro en URL (GET) - Útil para compatibilidad con ciertos servidores o proxies
    if (isset($_GET['token'])) {
        return $_GET['token'];
    }

    return false;
}

/**
 * VERIFICAR SI TOKEN NECESITA REFRESH
 */
function needsRefresh($token)
{
    $validation = validateJWT($token);

    if (!$validation || !$validation['valid']) {
        return false;
    }

    $timeRemaining = $validation['time_remaining'];
    return ($timeRemaining < JWT_REFRESH_TIME);
}

/**
 * OBTENER INFO DEL TOKEN
 */
function getTokenInfo($token)
{
    try {
        $token = str_replace('Bearer ', '', trim($token));

        if (empty($token)) {
            return false;
        }

        $parts = explode('.', $token);
        if (count($parts) !== 3) {
            return false;
        }

        $payload = json_decode(base64_decode($parts[1]), true);

        if (!$payload) {
            return false;
        }

        return [
            'issued_at' => date('Y-m-d H:i:s', $payload['iat'] ?? 0),
            'expires_at' => date('Y-m-d H:i:s', $payload['exp'] ?? 0),
            'time_remaining' => ($payload['exp'] ?? 0) - time(),
            'is_expired' => (($payload['exp'] ?? 0) < time()),
            'user' => $payload['user_data']['usuario'] ?? 'unknown',
            'rol' => $payload['user_data']['rol'] ?? 'unknown',
        ];

    } catch (Exception $e) {
        return false;
    }
}

/**
 * RENOVAR TOKEN JWT
 */
function refreshJWT($oldToken)
{
    $validation = validateJWT($oldToken);

    if (!$validation || !$validation['valid']) {
        return false;
    }

    return generateJWT($validation['user_data']);
}

?>