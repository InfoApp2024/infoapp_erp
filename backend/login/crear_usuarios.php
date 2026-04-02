<?php
// crear_usuarios.php - Adaptado al patrón de auth_middleware

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_crear_usuarios.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

require_once 'auth_middleware.php';

// Validar que la función existe antes de llamarla para evitar errores fatales (seguridad)
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
} else {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With");
    header("Access-Control-Allow-Methods: GET, POST, OPTIONS");
    header("Content-Type: application/json; charset=utf-8");
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    log_debug("========================================");
    log_debug("🆕 NUEVA REQUEST - CREAR USUARIO");
    log_debug("========================================");

    $auth = requireAuth();
    $currentUser = $auth['user'] ?? $auth; // Handle different structures if any

    // DEBUG CRÍTICO: Ver qué trae exactamente el usuario
    log_debug("� DEBUG USUARIO: " . print_r($currentUser, true));

    // Si $currentUser es null o vacío, algo falló
    if (!$currentUser) {
        log_debug("❌ Error: Usuario es null después de requireAuth");
    }

    log_debug("�👤 Usuario: " . ($currentUser['usuario'] ?? 'N/A') . " (ID: " . ($currentUser['id'] ?? 'N/A') . ")");
    log_debug("🔑 Rol detectado: '" . ($currentUser['rol'] ?? 'VACIO') . "'");

    // Corrección posible: A veces el rol viene en 'tipo_rol' o 'role'
    if (empty($currentUser['rol'])) {
        if (!empty($currentUser['TIPO_ROL']))
            $currentUser['rol'] = $currentUser['TIPO_ROL'];
        if (!empty($currentUser['role']))
            $currentUser['rol'] = $currentUser['role'];
    }

    logAccess($currentUser, '/crear_usuarios.php', 'create_user');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        log_debug("❌ Método no permitido");
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // Verificar permisos - incluir todos los roles admin
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    if (!$esAdmin) {
        log_debug("❌ Sin permisos para crear usuarios. Rol actual: " . $currentUser['rol']);
        sendJsonResponse(errorResponse('Solo administradores pueden crear usuarios. Tu rol es: ' . $currentUser['rol']), 403);
    }

    log_debug("✅ Permisos verificados");

    require '../conexion.php';

    // Auto-repair: Ensure ID_ESPECIALIDAD exists
    $colCheck = $conn->query("SHOW COLUMNS FROM usuarios LIKE 'ID_ESPECIALIDAD'");
    if ($colCheck && $colCheck->num_rows == 0) {
        log_debug("🔧 Columna ID_ESPECIALIDAD faltante. Agregando...");
        $sqlAlter = "ALTER TABLE usuarios ADD COLUMN ID_ESPECIALIDAD INT NULL AFTER ID_POSICION";
        if ($conn->query($sqlAlter)) {
            log_debug("✅ Columna ID_ESPECIALIDAD agregada.");
            // Try to add FK
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
        // Intentar POST si no hay Content-Type
        log_debug("📥 Intentando $_POST...");
        $data = !empty($_POST) ? $_POST : [];
    }

    if (empty($data)) {
        log_debug("❌ No se recibieron datos");
        throw new Exception('No se recibieron datos');
    }

    log_debug("✅ Datos recibidos");

    // Validar campos requeridos
    $camposRequeridos = ['NOMBRE_USER', 'CONTRASEÑA', 'NOMBRE_CLIENTE', 'NIT', 'CORREO', 'TIPO_ROL'];
    $camposFaltantes = [];

    foreach ($camposRequeridos as $campo) {
        if (!isset($data[$campo]) || empty(trim($data[$campo]))) {
            $camposFaltantes[] = $campo;
        }
    }

    if (!empty($camposFaltantes)) {
        log_debug("❌ Campos faltantes: " . implode(", ", $camposFaltantes));
        throw new Exception('Campos requeridos: ' . implode(", ", $camposFaltantes));
    }

    log_debug("✅ Campos requeridos validados");

    // Preparar datos
    $nombre_user = trim($data['NOMBRE_USER']);
    $contraseña = trim($data['CONTRASEÑA']);
    $nombre_cliente = trim($data['NOMBRE_CLIENTE']);
    $nit = trim($data['NIT']);
    $correo = trim($data['CORREO']);
    $tipo_rol = trim($data['TIPO_ROL']);

    // Validaciones
    if (!filter_var($correo, FILTER_VALIDATE_EMAIL)) {
        log_debug("❌ Email inválido: $correo");
        throw new Exception('Email inválido');
    }

    if (strlen($contraseña) < 8) {
        log_debug("❌ Contraseña muy corta");
        throw new Exception('La contraseña debe tener al menos 8 caracteres');
    }

    $rolesPermitidos = ['admin', 'administrador', 'gerente', 'rh', 'colaborador', 'cliente'];
    if (!in_array($tipo_rol, $rolesPermitidos)) {
        log_debug("❌ Rol no válido: $tipo_rol");
        throw new Exception('Rol no válido');
    }

    log_debug("✅ Validaciones OK");

    // Verificar duplicados
    log_debug("🔍 Verificando duplicados...");
    $sqlCheck = "SELECT id FROM usuarios WHERE NOMBRE_USER = ? OR CORREO = ? LIMIT 1";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("ss", $nombre_user, $correo);
    $stmtCheck->execute();

    if ($stmtCheck->get_result()->num_rows > 0) {
        log_debug("❌ Usuario o correo duplicado");
        throw new Exception('El usuario o correo ya existe');
    }

    log_debug("✅ Sin duplicados");

    // Campos opcionales
    $telefono = isset($data['TELEFONO']) && !empty($data['TELEFONO']) ? trim($data['TELEFONO']) : null;
    $direccion = isset($data['DIRECCION']) && !empty($data['DIRECCION']) ? trim($data['DIRECCION']) : null;
    $fecha_nacimiento = isset($data['FECHA_NACIMIENTO']) && !empty($data['FECHA_NACIMIENTO']) ? trim($data['FECHA_NACIMIENTO']) : null;
    $tipo_identificacion = isset($data['TIPO_IDENTIFICACION']) && !empty($data['TIPO_IDENTIFICACION']) ? trim($data['TIPO_IDENTIFICACION']) : null;
    $numero_identificacion = isset($data['NUMERO_IDENTIFICACION']) && !empty($data['NUMERO_IDENTIFICACION']) ? trim($data['NUMERO_IDENTIFICACION']) : null;
    $codigo_staff = isset($data['CODIGO_STAFF']) && !empty($data['CODIGO_STAFF']) ? trim($data['CODIGO_STAFF']) : null;
    $fecha_contratacion = isset($data['FECHA_CONTRATACION']) && !empty($data['FECHA_CONTRATACION']) ? trim($data['FECHA_CONTRATACION']) : null;
    $id_posicion = isset($data['ID_POSICION']) && !empty($data['ID_POSICION']) ? intval($data['ID_POSICION']) : null;
    $id_departamento = isset($data['ID_DEPARTAMENTO']) && !empty($data['ID_DEPARTAMENTO']) ? intval($data['ID_DEPARTAMENTO']) : null;
    $salario = isset($data['SALARIO']) && !empty($data['SALARIO']) ? floatval($data['SALARIO']) : null;
    $contacto_emergencia_nombre = isset($data['CONTACTO_EMERGENCIA_NOMBRE']) && !empty($data['CONTACTO_EMERGENCIA_NOMBRE']) ? trim($data['CONTACTO_EMERGENCIA_NOMBRE']) : null;
    $contacto_emergencia_telefono = isset($data['CONTACTO_EMERGENCIA_TELEFONO']) && !empty($data['CONTACTO_EMERGENCIA_TELEFONO']) ? trim($data['CONTACTO_EMERGENCIA_TELEFONO']) : null;
    $url_foto = isset($data['URL_FOTO']) && !empty($data['URL_FOTO']) ? trim($data['URL_FOTO']) : null;
    $id_especialidad = isset($data['ID_ESPECIALIDAD']) && !empty($data['ID_ESPECIALIDAD']) ? intval($data['ID_ESPECIALIDAD']) : null;
    $funcionario_id = isset($data['funcionario_id']) && !empty($data['funcionario_id']) ? intval($data['funcionario_id']) : null;
    $es_auditor = (isset($data['es_auditor']) && ($data['es_auditor'] === true || $data['es_auditor'] == 1)) ? 1 : 0;
    $can_edit_closed_ops = (isset($data['can_edit_closed_ops']) && ($data['can_edit_closed_ops'] === true || $data['can_edit_closed_ops'] == 1)) ? 1 : 0;

    // Hashear contraseña
    $contraseña_hash = password_hash($contraseña, PASSWORD_BCRYPT);

    $usuario_id = $currentUser['id'];

    // Obtener datos de organización del usuario creador para heredar
    $stmtOrg = $conn->prepare("SELECT ID_REGISTRO, NOMBRE_CLIENTE, NIT, DIRECCION, TELEFONO, regimen_tributario, SITIO_WEB, RESOLUCION_DIAN, INSTAGRAM, FACEBOOK, WHATSAPP, NOMBRE_CONTACTO, CIUDAD FROM usuarios WHERE id = ?");
    $stmtOrg->bind_param("i", $usuario_id);
    $stmtOrg->execute();
    $resOrg = $stmtOrg->get_result();
    $orgData = $resOrg->fetch_assoc();
    $stmtOrg->close();

    $id_registro = $orgData['ID_REGISTRO'] ?? 'dev';

    // Sobreescribir NOMBRE_CLIENTE con el de la organización del admin
    // Usamos el operador de fusión de null para asegurar que copiamos el valor
    // incluso si es vacío, para evitar que quede el nombre de usuario (que envía la app por defecto)
    $nombre_cliente = $orgData['NOMBRE_CLIENTE'] ?? $nombre_cliente;

    log_debug("🏢 Heredando organización: ID_REGISTRO=$id_registro, CLIENTE=$nombre_cliente");

    $sql = "INSERT INTO usuarios (
                NOMBRE_CLIENTE, NIT, CORREO, NOMBRE_USER, TIPO_ROL, CONTRASEÑA, ESTADO_USER,
                TELEFONO, DIRECCION, FECHA_NACIMIENTO, TIPO_IDENTIFICACION, NUMERO_IDENTIFICACION,
                CODIGO_STAFF, FECHA_CONTRATACION, ID_POSICION, ID_DEPARTAMENTO, SALARIO,
                CONTACTO_EMERGENCIA_NOMBRE, CONTACTO_EMERGENCIA_TELEFONO, URL_FOTO, USUARIO_ACTUALIZACION, ID_ESPECIALIDAD,
                ID_REGISTRO, funcionario_id, es_auditor, can_edit_closed_ops,
                regimen_tributario, SITIO_WEB, RESOLUCION_DIAN, INSTAGRAM, FACEBOOK, WHATSAPP, NOMBRE_CONTACTO, CIUDAD
            ) VALUES (
                ?, ?, ?, ?, ?, ?, 'activo',
                ?, ?, ?, ?, ?, 
                ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?,
                ?, ?, ?, ?,
                ?, ?, ?, ?, ?, ?, ?, ?
            )";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        log_debug("❌ Error preparando query: " . $conn->error);
        throw new Exception('Error preparando consulta');
    }

    // Datos de la empresa heredados
    $nit = $orgData['NIT'] ?? $nit;
    $direccion = $orgData['DIRECCION'] ?? $direccion;
    $telefono = $orgData['TELEFONO'] ?? $telefono;
    $regimen = $orgData['regimen_tributario'] ?? '';
    $sitio_web = $orgData['SITIO_WEB'] ?? '';
    $resolucion = $orgData['RESOLUCION_DIAN'] ?? '';
    $instagram = $orgData['INSTAGRAM'] ?? '';
    $facebook = $orgData['FACEBOOK'] ?? '';
    $whatsapp = $orgData['WHATSAPP'] ?? '';
    $contacto_emp = $orgData['NOMBRE_CONTACTO'] ?? '';
    $ciudad = $orgData['CIUDAD'] ?? '';

    $stmt->bind_param(
        "sssssssssssssiissssiisiii" . "ssssssss",
        $nombre_cliente,
        $nit,
        $correo,
        $nombre_user,
        $tipo_rol,
        $contraseña_hash,
        $telefono,
        $direccion,
        $fecha_nacimiento,
        $tipo_identificacion,
        $numero_identificacion,
        $codigo_staff,
        $fecha_contratacion,
        $id_posicion,
        $id_departamento,
        $salario,
        $contacto_emergencia_nombre,
        $contacto_emergencia_telefono,
        $url_foto,
        $usuario_id,
        $id_especialidad,
        $id_registro,
        $funcionario_id,
        $es_auditor,
        $can_edit_closed_ops,
        $regimen,
        $sitio_web,
        $resolucion,
        $instagram,
        $facebook,
        $whatsapp,
        $contacto_emp,
        $ciudad
    );

    if (!$stmt->execute()) {
        log_debug("❌ Error ejecutando insert: " . $stmt->error);
        throw new Exception('Error al crear usuario');
    }

    $nuevoUsuarioId = $conn->insert_id;
    log_debug("✅ Usuario creado con ID: $nuevoUsuarioId");

    // Obtener usuario creado
    $sqlSelect = "SELECT * FROM usuarios WHERE id = ? LIMIT 1";
    $stmtSelect = $conn->prepare($sqlSelect);
    $stmtSelect->bind_param("i", $nuevoUsuarioId);
    $stmtSelect->execute();
    $usuarioCreado = $stmtSelect->get_result()->fetch_assoc();

    sendJsonResponse([
        'success' => true,
        'message' => 'Usuario creado exitosamente',
        'id' => $nuevoUsuarioId,
        'data' => buildUserResponse($usuarioCreado, $currentUser['rol'])
    ], 201);

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
        $response['salario'] = $usuario['SALARIO'] ?? null;
    }

    return $response;
}
?>