<?php
// eliminar_usuarios.php - Adaptado al patrón de auth_middleware
// COMPORTAMIENTO: Elimina permanentemente por defecto

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_eliminar_usuarios.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

require_once 'auth_middleware.php';

// Manejo de CORS y OPTIONS antes de cualquier otra lógica
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
} else {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, User-ID");
    header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
    header("Content-Type: application/json; charset=utf-8");
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    log_debug("========================================");
    log_debug("🗑️  NUEVA REQUEST - ELIMINAR USUARIO");
    log_debug("========================================");

    $auth = requireAuth();
    $currentUser = $auth['user'] ?? $auth;
    log_debug("👤 Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);

    // Corrección de roles (igual que en crear_usuarios.php)
    if (empty($currentUser['rol'])) {
        if (!empty($currentUser['TIPO_ROL'])) {
            $currentUser['rol'] = $currentUser['TIPO_ROL'];
        }
        if (!empty($currentUser['role'])) {
            $currentUser['rol'] = $currentUser['role'];
        }
    }
    log_debug("🔑 Rol normalizado: '" . ($currentUser['rol'] ?? 'VACIO') . "'");

    logAccess($currentUser, '/eliminar_usuarios.php', 'delete_user');

    // Aceptar DELETE o POST (Web puede enviar POST por CORS)
    if ($_SERVER['REQUEST_METHOD'] !== 'DELETE' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido. Use DELETE o POST'), 405);
    }

    log_debug("✅ Método HTTP válido");

    // Log keys for debugging - USANDO PRINT_R PARA EVITAR ERROR 500 SI NO ES ARRAY
    // log_debug("🔑 Keys usuario: " . implode(", ", array_keys($currentUser))); 
    log_debug("👤 Data user (safe): " . print_r($currentUser, true));

    // Verificar permisos - incluir todos los roles admin
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];

    // Convertir a minúsculas para comparar
    $rolActual = strtolower($currentUser['rol'] ?? '');
    log_debug("👮 Rol para verificar: '$rolActual'");

    $esAdmin = in_array($rolActual, $rolesAdmin);

    if (!$esAdmin) {
        log_debug("❌ Sin permisos para eliminar usuarios. Rol: '$rolActual'");
        // Incluir el rol detectado en el mensaje de error para depurar
        sendJsonResponse(errorResponse('Solo administradores pueden eliminar usuarios. Tu rol detectado es: ' . ($currentUser['rol'] ?? 'VACIO')), 403);
    }

    log_debug("✅ Permisos verificados");

    require '../conexion.php';

    log_debug("📥 Leyendo datos...");

    // Detectar Content-Type
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    log_debug("📋 Content-Type: $contentType");

    $data = [];

    if (strpos($contentType, 'application/json') !== false) {
        // JSON
        log_debug("📥 Parseando como JSON...");
        $input = file_get_contents("php://input");
        $data = json_decode($input, true);

        if (!$data && !empty($input)) {
            log_debug("❌ JSON inválido");
            throw new Exception('Datos JSON inválidos');
        }
    } else if (strpos($contentType, 'application/x-www-form-urlencoded') !== false) {
        // Form-urlencoded
        log_debug("📥 Parseando como form-urlencoded...");
        parse_str(file_get_contents("php://input"), $data);
    } else {
        // Intentar POST/GET si no hay Content-Type
        log_debug("📥 Intentando $_POST y $_GET...");
        $data = !empty($_POST) ? $_POST : $_GET;
    }

    if (empty($data)) {
        log_debug("❌ No se recibieron datos");
        throw new Exception('No se recibieron datos');
    }

    log_debug("✅ Datos recibidos");

    // Obtener ID del usuario a eliminar
    if (!isset($data['id']) || empty($data['id'])) {
        log_debug("❌ ID no proporcionado");
        throw new Exception('El ID del usuario es requerido');
    }

    $id_usuario = intval($data['id']);
    log_debug("🔍 Eliminando usuario ID: $id_usuario");

    // No permitir auto-eliminación
    if ($id_usuario == $currentUser['id']) {
        log_debug("❌ Intento de auto-eliminación");
        sendJsonResponse(errorResponse('No puedes eliminar tu propia cuenta'), 403);
    }

    // Verificar que existe
    log_debug("✓ Verificando que el usuario existe...");
    $sqlCheck = "SELECT * FROM usuarios WHERE id = ? LIMIT 1";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("i", $id_usuario);
    $stmtCheck->execute();
    $resultCheck = $stmtCheck->get_result();

    if ($resultCheck->num_rows === 0) {
        log_debug("❌ Usuario no encontrado");
        sendJsonResponse(errorResponse('Usuario no encontrado'), 404);
    }

    $usuarioExistente = $resultCheck->fetch_assoc();
    log_debug("✅ Usuario encontrado: " . $usuarioExistente['NOMBRE_USER']);

    // Obtener tipo de eliminación (por defecto: eliminar permanentemente)
    $tipo_eliminacion = isset($data['tipo']) ? trim(strtolower($data['tipo'])) : 'eliminar';

    if (!in_array($tipo_eliminacion, ['desactivar', 'eliminar'])) {
        log_debug("❌ Tipo de eliminación inválido: $tipo_eliminacion");
        throw new Exception("Tipo de eliminación debe ser 'desactivar' o 'eliminar'");
    }

    log_debug("📋 Tipo de eliminación: $tipo_eliminacion");

    $razon_eliminacion = isset($data['razon']) && !empty($data['razon']) ? trim($data['razon']) : null;

    // Ejecutar eliminación
    if ($tipo_eliminacion === 'eliminar') {
        // HARD DELETE: Eliminación permanente (POR DEFECTO)
        // Requerir confirmación explícita como seguridad
        if (!isset($data['confirmar']) || $data['confirmar'] !== true) {
            log_debug("❌ Eliminación permanente sin confirmación");
            sendJsonResponse(errorResponse('Se requiere confirmación: enviar "confirmar": true'), 400);
        }

        log_debug("🔴 Ejecutando hard delete...");

        // Eliminar dependencias en registros_geocerca primero (Cascade Delete manual)
        $stmtDep = $conn->prepare("DELETE FROM registros_geocerca WHERE usuario_id = ?");
        if ($stmtDep) {
            $stmtDep->bind_param("i", $id_usuario);
            $stmtDep->execute();
            $stmtDep->close();
            log_debug("   -> Dependencias en registros_geocerca eliminadas");
        }

        $sql = "DELETE FROM usuarios WHERE id = ?";
        $stmt = $conn->prepare($sql);

        if (!$stmt) {
            log_debug("❌ Error preparando query: " . $conn->error);
            throw new Exception('Error preparando consulta');
        }

        $stmt->bind_param("i", $id_usuario);

        if (!$stmt->execute()) {
            log_debug("❌ Error ejecutando delete: " . $stmt->error);
            throw new Exception('Error al eliminar usuario');
        }

        log_debug("✅ Usuario eliminado permanentemente");
        $accion = "eliminado permanentemente";
        $mensaje_respuesta = "Usuario eliminado permanentemente";

    } else {
        // SOFT DELETE: Marcar como inactivo
        log_debug("🔄 Ejecutando soft delete...");

        $fecha_hora = date('Y-m-d H:i:s');
        $usuario_id = $currentUser['id'];

        $sql = "UPDATE usuarios 
                SET ESTADO_USER = 'inactivo', 
                    USUARIO_ACTUALIZACION = ?
                WHERE id = ?";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            log_debug("❌ Error preparando query: " . $conn->error);
            throw new Exception('Error preparando consulta');
        }

        $stmt->bind_param("ii", $usuario_id, $id_usuario);

        if (!$stmt->execute()) {
            log_debug("❌ Error ejecutando update: " . $stmt->error);
            throw new Exception('Error al desactivar usuario');
        }

        log_debug("✅ Usuario desactivado");
        $accion = "desactivado";
        $mensaje_respuesta = "Usuario desactivado exitosamente";
    }

    log_debug("✅ Operación completada exitosamente");

    sendJsonResponse([
        'success' => true,
        'message' => $mensaje_respuesta,
        'data' => [
            'id' => $id_usuario,
            'usuario' => $usuarioExistente['NOMBRE_USER'],
            'nombre_completo' => $usuarioExistente['NOMBRE_CLIENTE'],
            'accion' => $accion,
            'fecha_accion' => date('Y-m-d H:i:s'),
            'realizado_por' => $currentUser['usuario'],
            'razon' => $razon_eliminacion ?? 'No especificada'
        ]
    ], 200);

} catch (Throwable $e) {
    log_debug("🔴 Exception/Error: " . $e->getMessage());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    log_debug("========================================\n");
}
?>