<?php
// API_Infoapp/login/permissions/update_user_permissions.php
// Actualiza el set de permisos por usuario a partir de una matriz módulo->acciones.

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_update_user_permissions.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

// PASO 0: Configurar CORS
// Validar que la función existe antes de llamarla para evitar errores fatales (seguridad)
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
} else {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
    header("Access-Control-Allow-Methods: POST, PUT, OPTIONS");
    header("Content-Type: application/json; charset=utf-8");
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit(0);
}

function is_valid_action(string $a): bool
{
    static $allowed = ['listar', 'crear', 'actualizar', 'eliminar', 'ver', 'exportar', 'filtrar', 'configurar_columnas', 'desbloquear', 'monitoreo'];
    return in_array($a, $allowed, true);
}

try {
    // PASO 1: Requerir autenticación JWT
    require_once '../auth_middleware.php';
    $currentUser = requireAuth();

    log_debug("========================================");
    log_debug("🔄 REQUEST - UPDATE USER PERMISSIONS");
    log_debug("👤 Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    // PASO 2: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 3: Log de acceso
    logAccess($currentUser, '/login/permissions/update_user_permissions.php', 'update_permissions');

    // PASO 4: Leer datos del body
    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        log_debug("❌ JSON inválido o vacío");
        sendJsonResponse(errorResponse('Datos JSON inválidos'), 400);
    }

    $userId = isset($input['user_id']) ? (int) $input['user_id'] : null;
    $permissions = isset($input['permissions']) ? $input['permissions'] : null;

    log_debug("📝 user_id: $userId, permissions: " . json_encode($permissions));

    if (!$userId || $userId <= 0 || !is_array($permissions)) {
        log_debug("❌ Datos inválidos - user_id: $userId, permissions es array: " . (is_array($permissions) ? 'sí' : 'no'));
        sendJsonResponse(errorResponse('user_id y permissions array son requeridos'), 400);
    }

    // Solo admin puede modificar permisos
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    if (!$esAdmin) {
        log_debug("❌ Sin permisos - rol: " . $currentUser['rol']);
        sendJsonResponse(errorResponse('Solo administradores pueden actualizar permisos'), 403);
    }

    log_debug("✅ Validaciones OK");

    // PASO 5: Conexión a BD
    require '../../conexion.php';

    log_debug("🔄 Iniciando transacción...");

    $conn->begin_transaction();

    try {
        // Limpiar permisos existentes del usuario
        log_debug("🗑️  Eliminando permisos existentes para user_id: $userId");

        $sqlDelete = "DELETE FROM user_permissions WHERE user_id = ?";
        $stmtDelete = $conn->prepare($sqlDelete);

        if (!$stmtDelete) {
            throw new Exception('Error preparando DELETE: ' . $conn->error);
        }

        $stmtDelete->bind_param("i", $userId);

        if (!$stmtDelete->execute()) {
            throw new Exception('Error ejecutando DELETE: ' . $stmtDelete->error);
        }

        log_debug("✅ Permisos existentes eliminados");

        // Insertar nuevos permisos
        log_debug("➕ Insertando nuevos permisos...");

        $sqlInsert = "INSERT INTO user_permissions (user_id, module, action, allowed) VALUES (?, ?, ?, 1)";
        $stmtInsert = $conn->prepare($sqlInsert);

        if (!$stmtInsert) {
            throw new Exception('Error preparando INSERT: ' . $conn->error);
        }

        $insertCount = 0;
        foreach ($permissions as $module => $actions) {
            if (!is_string($module) || !is_array($actions)) {
                log_debug("⚠️  Módulo inválido o acciones no es array: $module");
                continue;
            }

            $module = trim($module);

            foreach ($actions as $a) {
                if (!is_string($a)) {
                    log_debug("⚠️  Acción no es string en módulo $module");
                    continue;
                }

                $a = trim($a);

                if (!is_valid_action($a)) {
                    log_debug("⚠️  Acción no válida: $a en módulo $module");
                    continue;
                }

                $stmtInsert->bind_param("iss", $userId, $module, $a);

                if (!$stmtInsert->execute()) {
                    throw new Exception('Error insertando permiso: ' . $stmtInsert->error);
                }

                $insertCount++;
                log_debug("  ✓ Insertado: $module -> $a");
            }
        }

        log_debug("✅ Total de permisos insertados: $insertCount");

        // Confirmar transacción
        $conn->commit();
        log_debug("✅ Transacción confirmada");

        sendJsonResponse([
            'success' => true,
            'message' => 'Permisos actualizados exitosamente',
            'user_id' => $userId,
            'permissions_count' => $insertCount,
            'updated_by' => $currentUser['usuario']
        ], 200);

    } catch (Exception $e) {
        log_debug("❌ Error en transacción: " . $e->getMessage());
        $conn->rollback();
        throw $e;
    }

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