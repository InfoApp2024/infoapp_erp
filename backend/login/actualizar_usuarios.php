<?php
// actualizar_usuarios.php - Adaptado al patrón de auth_middleware
// CORREGIDO: bind_param ahora funciona correctamente con referencias

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_actualizar_usuarios.txt');

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
    log_debug("🆕 NUEVA REQUEST - ACTUALIZAR USUARIO");
    log_debug("========================================");

    $currentUser = requireAuth();
    log_debug("👤 Usuario: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    log_debug("📨 Método: " . $_SERVER['REQUEST_METHOD']);

    logAccess($currentUser, '/actualizar_usuarios.php', 'update_user');

    // Aceptar PUT o POST (Web puede enviar POST por CORS)
    if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido. Use PUT o POST'), 405);
    }

    log_debug("✅ Método HTTP válido");

    require '../conexion.php';

    // Auto-repair: Ensure ID_ESPECIALIDAD exists
    $colCheck = $conn->query("SHOW COLUMNS FROM usuarios LIKE 'ID_ESPECIALIDAD'");
    if ($colCheck && $colCheck->num_rows == 0) {
        log_debug("🔧 Columna ID_ESPECIALIDAD faltante. Agregando...");
        $sqlAlter = "ALTER TABLE usuarios ADD COLUMN ID_ESPECIALIDAD INT NULL AFTER ID_POSICION";
        if ($conn->query($sqlAlter)) {
            log_debug("✅ Columna ID_ESPECIALIDAD agregada.");
            // Try to add FK - ignore error if fails
            try {
                $conn->query("ALTER TABLE usuarios ADD CONSTRAINT fk_usuario_especialidad FOREIGN KEY (ID_ESPECIALIDAD) REFERENCES especialidades(id) ON DELETE SET NULL");
            } catch (Exception $ex) {
                log_debug("⚠️ No se pudo agregar FK: " . $ex->getMessage());
            }
        } else {
            log_debug("❌ Error agregando columna: " . $conn->error);
        }
    }

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
        // Intentar GET si POST/PUT está vacío
        log_debug("📥 Intentando $_POST y $_GET...");
        $data = !empty($_POST) ? $_POST : $_GET;
    }

    if (empty($data)) {
        log_debug("❌ No se recibieron datos");
        throw new Exception('No se recibieron datos');
    }

    log_debug("✅ Datos recibidos: " . json_encode($data));

    // Obtener ID
    if (!isset($data['id']) || empty($data['id'])) {
        log_debug("❌ ID no proporcionado");
        throw new Exception('El ID del usuario es requerido');
    }

    $id_usuario = intval($data['id']);
    log_debug("🔍 Actualizando usuario ID: $id_usuario");

    // Verificar que existe
    $sqlCheck = "SELECT * FROM usuarios WHERE id = ? LIMIT 1";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("i", $id_usuario);
    $stmtCheck->execute();

    if ($stmtCheck->get_result()->num_rows === 0) {
        log_debug("❌ Usuario no encontrado");
        sendJsonResponse(errorResponse('Usuario no encontrado'), 404);
    }

    // Verificar permisos - incluir todos los roles admin
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    log_debug("🔐 ¿Es admin?: " . ($esAdmin ? 'SÍ' : 'NO'));

    if (!$esAdmin && $id_usuario != $currentUser['id']) {
        log_debug("❌ Intento de actualizar otro usuario sin permisos");
        sendJsonResponse(errorResponse('No puedes actualizar otros usuarios'), 403);
    }

    log_debug("✅ Permisos verificados");

    // Construir UPDATE dinámico
    $campos = [];
    $valores = [];
    $tipos = "";

    // Campos que todos pueden actualizar
    $camposPublicos = [
        'NOMBRE_USER',
        'NOMBRE_CLIENTE',
        'CORREO',
        'CONTRASEÑA',
        'TELEFONO',
        'DIRECCION',
        'FECHA_NACIMIENTO',
        'TIPO_IDENTIFICACION',
        'NUMERO_IDENTIFICACION',
        'CONTACTO_EMERGENCIA_NOMBRE',
        'CONTACTO_EMERGENCIA_TELEFONO',
        'URL_FOTO',
        'NIT'
    ];

    // Campos solo admin
    $camposAdmin = [
        'TIPO_ROL',
        'ESTADO_USER',
        'CODIGO_STAFF',
        'FECHA_CONTRATACION',
        'ID_POSICION',
        'ID_DEPARTAMENTO',
        'ID_ESPECIALIDAD',
        'SALARIO',
        'funcionario_id',
        'es_auditor',
        'can_edit_closed_ops'
    ];

    foreach ($camposPublicos as $campo) {
        if (isset($data[$campo])) {
            if ($campo === 'CONTRASEÑA') {
                if (strlen(trim($data[$campo])) < 8) {
                    throw new Exception('La contraseña debe tener al menos 8 caracteres');
                }
                $valor = password_hash($data[$campo], PASSWORD_BCRYPT);
                log_debug("   ✏️ $campo (hasheada)");
            } else if ($campo === 'CORREO') {
                $valor = trim($data[$campo]);
                // Validar email
                if (!filter_var($valor, FILTER_VALIDATE_EMAIL)) {
                    throw new Exception('Email inválido');
                }
                // Verificar duplicado
                $sqlMailCheck = "SELECT id FROM usuarios WHERE CORREO = ? AND id != ? LIMIT 1";
                $stmtMailCheck = $conn->prepare($sqlMailCheck);
                $stmtMailCheck->bind_param("si", $valor, $id_usuario);
                $stmtMailCheck->execute();
                if ($stmtMailCheck->get_result()->num_rows > 0) {
                    throw new Exception('El correo ya está en uso');
                }
                log_debug("   ✏️ $campo");
            } else if ($campo === 'NOMBRE_USER') {
                $valor = trim($data[$campo]);
                if (empty($valor)) {
                    throw new Exception('El usuario es requerido');
                }
                // Verificar duplicado
                $sqlUserCheck = "SELECT id FROM usuarios WHERE NOMBRE_USER = ? AND id != ? LIMIT 1";
                $stmtUserCheck = $conn->prepare($sqlUserCheck);
                $stmtUserCheck->bind_param("si", $valor, $id_usuario);
                $stmtUserCheck->execute();
                if ($stmtUserCheck->get_result()->num_rows > 0) {
                    throw new Exception('El nombre de usuario ya está en uso');
                }
                log_debug("   ✏️ $campo");
            } else {
                $valor = isset($data[$campo]) && !empty($data[$campo]) ? trim($data[$campo]) : null;
                log_debug("   ✏️ $campo");
            }

            $campos[] = "$campo = ?";
            $valores[] = $valor;
            $tipos .= "s";
        }
    }

    if ($esAdmin) {
        foreach ($camposAdmin as $campo) {
            if (isset($data[$campo])) {
                if ($campo === 'TIPO_ROL') {
                    $rolesPermitidos = ['admin', 'administrador', 'gerente', 'rh', 'colaborador', 'cliente'];
                    if (!in_array($data[$campo], $rolesPermitidos)) {
                        throw new Exception('Rol no válido');
                    }
                    $valor = $data[$campo];
                    log_debug("   ✏️ $campo (admin)");
                } else if ($campo === 'ESTADO_USER') {
                    $estadosPermitidos = ['activo', 'inactivo', 'suspendido'];
                    if (!in_array($data[$campo], $estadosPermitidos)) {
                        throw new Exception('Estado no válido');
                    }
                    $valor = $data[$campo];
                    log_debug("   ✏️ $campo (admin)");
                } else if ($campo === 'CODIGO_STAFF') {
                    $valor = !empty($data[$campo]) ? trim($data[$campo]) : null;
                    if (!empty($valor)) {
                        $sqlCodeCheck = "SELECT id FROM usuarios WHERE CODIGO_STAFF = ? AND id != ? LIMIT 1";
                        $stmtCodeCheck = $conn->prepare($sqlCodeCheck);
                        $stmtCodeCheck->bind_param("si", $valor, $id_usuario);
                        $stmtCodeCheck->execute();
                        if ($stmtCodeCheck->get_result()->num_rows > 0) {
                            throw new Exception('El código STAFF ya está en uso');
                        }
                    }
                    log_debug("   ✏️ $campo (admin)");
                } else if (in_array($campo, ['ID_POSICION', 'ID_DEPARTAMENTO', 'ID_ESPECIALIDAD'])) {
                    $valor = !empty($data[$campo]) ? intval($data[$campo]) : null;
                    $tipos .= "i";
                    $campos[] = "$campo = ?";
                    $valores[] = $valor;
                    log_debug("   ✏️ $campo (admin) - int");
                    continue;
                } else if ($campo === 'SALARIO') {
                    $valor = !empty($data[$campo]) ? floatval($data[$campo]) : null;
                    $tipos .= "d";
                    $campos[] = "$campo = ?";
                    $valores[] = $valor;
                    log_debug("   ✏️ $campo (admin) - decimal");
                    continue;
                    log_debug("   ✏️ $campo (admin) - bool/int");
                    continue;
                } else if ($campo === 'can_edit_closed_ops' || $campo === 'es_auditor') {
                    $valor = (isset($data[$campo]) && ($data[$campo] === true || $data[$campo] == 1)) ? 1 : 0;
                    $tipos .= "i";
                    $campos[] = "$campo = ?";
                    $valores[] = $valor;
                    log_debug("   ✏️ $campo (admin) - bool/int");
                    continue;
                } else {
                    $valor = !empty($data[$campo]) ? trim($data[$campo]) : null;
                    log_debug("   ✏️ $campo (admin)");
                }

                $campos[] = "$campo = ?";
                $valores[] = $valor;
                $tipos .= "s";
            }
        }
    }

    if (empty($campos)) {
        log_debug("❌ No se proporcionaron campos para actualizar");
        throw new Exception('No se proporcionaron campos para actualizar');
    }

    // Agregar auditoría
    $campos[] = "USUARIO_ACTUALIZACION = ?";
    $valores[] = $currentUser['id'];
    $tipos .= "i";

    log_debug("✅ Campos a actualizar: " . count($campos));

    // Ejecutar UPDATE
    $sql = "UPDATE usuarios SET " . implode(", ", $campos) . " WHERE id = ?";
    $valores[] = $id_usuario;
    $tipos .= "i";

    log_debug("📝 Ejecutando UPDATE...");
    log_debug("📝 SQL: $sql");
    log_debug("📝 Tipos: $tipos | Total parámetros: " . count($valores));

    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("❌ Error preparando query: " . $conn->error);
        throw new Exception('Error preparando consulta');
    }

    // FIX: bind_param requiere referencias, no valores
    // Usar call_user_func_array para pasar referencias correctamente
    $referencias = array();
    foreach ($valores as $key => $value) {
        $referencias[$key] = &$valores[$key];
    }
    call_user_func_array(array($stmt, 'bind_param'), array_merge(array($tipos), $referencias));

    if (!$stmt->execute()) {
        log_debug("❌ Error ejecutando update: " . $stmt->error);
        throw new Exception('Error al actualizar usuario');
    }

    log_debug("✅ Usuario actualizado exitosamente");

    // Obtener usuario actualizado
    $sqlSelect = "SELECT * FROM usuarios WHERE id = ? LIMIT 1";
    $stmtSelect = $conn->prepare($sqlSelect);
    $stmtSelect->bind_param("i", $id_usuario);
    $stmtSelect->execute();
    $usuarioActualizado = $stmtSelect->get_result()->fetch_assoc();

    sendJsonResponse([
        'success' => true,
        'message' => 'Usuario actualizado exitosamente',
        'data' => buildUserResponse($usuarioActualizado, $currentUser['rol'])
    ]);
} catch (Exception $e) {
    log_debug("🔴 Exception: " . $e->getMessage());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    log_debug("========================================\n");
}

function buildUserResponse($usuario, $rol)
{
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($rol, $rolesAdmin);

    $response = [
        "id" => (int) $usuario['id'],
        "usuario" => $usuario['NOMBRE_USER'],
        "rol" => $usuario['TIPO_ROL'],
        "estado" => $usuario['ESTADO_USER'],
        "nombre_completo" => $usuario['NOMBRE_CLIENTE'] ?? null,
        "correo" => $usuario['CORREO'] ?? null,
        "nit" => $usuario['NIT'] ?? null,
        "telefono" => $usuario['TELEFONO'] ?? null,
        "direccion" => $usuario['DIRECCION'] ?? null,
        "fecha_nacimiento" => $usuario['FECHA_NACIMIENTO'] ?? null,
        "tipo_identificacion" => $usuario['TIPO_IDENTIFICACION'] ?? null,
        "numero_identificacion" => $usuario['NUMERO_IDENTIFICACION'] ?? null,
        "codigo_staff" => $usuario['CODIGO_STAFF'] ?? null,
        "url_foto" => $usuario['URL_FOTO'] ?? null,
        "contacto_emergencia_nombre" => $usuario['CONTACTO_EMERGENCIA_NOMBRE'] ?? null,
        "contacto_emergencia_telefono" => $usuario['CONTACTO_EMERGENCIA_TELEFONO'] ?? null,
        "funcionario_id" => isset($usuario['funcionario_id']) ? (int) $usuario['funcionario_id'] : null,
        "es_auditor" => isset($usuario['es_auditor']) ? (bool) $usuario['es_auditor'] : false,
        "can_edit_closed_ops" => isset($usuario['can_edit_closed_ops']) ? (bool) $usuario['can_edit_closed_ops'] : false,
    ];

    if ($esAdmin) {
        $response['fecha_contratacion'] = $usuario['FECHA_CONTRATACION'] ?? null;
        $response['id_posicion'] = $usuario['ID_POSICION'] ?? null;
        $response['id_departamento'] = $usuario['ID_DEPARTAMENTO'] ?? null;
        $response['id_especialidad'] = $usuario['ID_ESPECIALIDAD'] ?? null;
        $response['salario'] = $usuario['SALARIO'] ?? null;
    }

    return $response;
}
