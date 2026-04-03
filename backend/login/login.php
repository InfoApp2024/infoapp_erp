<?php
// login.php - Versión mejorada que enriquece la respuesta sin cambiar la consulta base
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

header("Access-Control-Allow-Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? '*'));
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Content-Type: application/json; charset=utf-8");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit();
}

function sendJsonResponse($data)
{
    echo json_encode($data);
    exit();
}

function handleError($message, $details = null)
{
    $response = [
        "success" => false,
        "message" => $message
    ];

    if ($details) {
        $response["debug"] = $details;
    }

    sendJsonResponse($response);
}

try {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        handleError("Método no permitido", "Se esperaba POST");
    }

    if (!file_exists('jwt_helper.php')) {
        handleError("Error del servidor", "jwt_helper.php no encontrado");
    }

    require_once 'jwt_helper.php';

    if (!file_exists('../conexion.php')) {
        handleError("Error del servidor", "conexion.php no encontrado");
    }

    if (!file_exists('../conexion_admin.php')) {
        handleError("Error del servidor", "conexion_admin.php no encontrado");
    }

    require '../conexion.php';
    require '../conexion_admin.php';

    $input = file_get_contents("php://input");
    if (empty($input)) {
        handleError("Datos incompletos", "No se recibieron datos");
    }

    $data = json_decode($input);
    if ($data === null) {
        handleError("Datos inválidos", "Error al parsear JSON");
    }

    if (!isset($data->NOMBRE_USER) || !isset($data->CONTRASEÑA)) {
        handleError("Datos incompletos", "NOMBRE_USER y CONTRASEÑA son requeridos");
    }

    if (empty($data->NOMBRE_USER) || empty($data->CONTRASEÑA)) {
        handleError("Datos incompletos", "Los campos no pueden estar vacíos");
    }

    $nombre_user = trim($data->NOMBRE_USER);
    $contrasena = trim($data->CONTRASEÑA);

    if (!isset($conn) || $conn->connect_error) {
        handleError("Error de conexión", "No se pudo conectar a la BD principal");
    }

    if (!isset($conn_admin) || $conn_admin->connect_error) {
        handleError("Error de conexión", "No se pudo conectar a la BD administrativa");
    }

    // MANTENER SELECT * para traer TODOS los campos (incluyendo los nuevos)
    $sql = "SELECT * FROM usuarios WHERE NOMBRE_USER = ? LIMIT 1";
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        handleError("Error de base de datos", "Error preparando consulta");
    }

    $stmt->bind_param("s", $nombre_user);

    if (!$stmt->execute()) {
        handleError("Error de base de datos", "Error ejecutando consulta");
    }

    $resultado = $stmt->get_result();

    if ($resultado->num_rows !== 1) {
        handleError("Usuario o contraseña no válidos");
    }

    $usuario = $resultado->fetch_assoc();

    if ($usuario['ESTADO_USER'] !== 'activo') {
        handleError("Usuario inactivo", "Contacte al administrador para activar su cuenta");
    }

    $id_registro = $usuario['ID_REGISTRO'];
    $sqlCliente = "SELECT estado FROM clientes WHERE id_registro = ? LIMIT 1";
    $stmtAdmin = $conn_admin->prepare($sqlCliente);

    if (!$stmtAdmin) {
        handleError("Error de base de datos", "Error preparando consulta administrativa");
    }

    $stmtAdmin->bind_param("s", $id_registro);

    if (!$stmtAdmin->execute()) {
        handleError("Error de base de datos", "Error ejecutando consulta administrativa");
    }

    $resCliente = $stmtAdmin->get_result();

    if ($resCliente->num_rows !== 1) {
        handleError("Cliente no registrado", "El cliente no está registrado");
    }

    $cliente = $resCliente->fetch_assoc();
    if ($cliente['estado'] !== 'activo') {
        handleError("Cliente inactivo", "El cliente está inactivo");
    }

    if (!password_verify($contrasena, $usuario['CONTRASEÑA'])) {
        handleError("Usuario o contraseña no válidos");
    }

    $rol = $usuario['TIPO_ROL'];
    $funcionario_id = $usuario['funcionario_id'] ?? null;
    $cliente_id_final = null;

    // Si es rol cliente, debemos obtener su cliente_id de la tabla funcionario
    if ($rol === 'cliente' && $funcionario_id) {
        $stmtFunc = $conn->prepare("SELECT cliente_id FROM funcionario WHERE id = ? AND activo = 1 LIMIT 1");
        $stmtFunc->bind_param("i", $funcionario_id);
        $stmtFunc->execute();
        $resFunc = $stmtFunc->get_result();
        if ($resFunc->num_rows === 1) {
            $fData = $resFunc->fetch_assoc();
            $cliente_id_final = $fData['cliente_id'];
        }
    }

    // Calcular es_auditor una sola vez para usar en JWT y respuesta
    $esAuditor = (function ($u) {
        foreach ($u as $k => $v) {
            if (strtoupper($k) === 'ES_AUDITOR')
                return (int) $v;
        }
        return 0;
    })($usuario);

    $userData = [
        'id' => (int) $usuario['id'],
        'usuario' => $usuario['NOMBRE_USER'],
        'rol' => $rol,
        'estado' => $usuario['ESTADO_USER'],
        'nombre_completo' => $usuario['NOMBRE_CLIENTE'] ?? null,
        'correo' => $usuario['CORREO'] ?? null,
        'nit' => $usuario['NIT'] ?? null,
        'funcionario_id' => $funcionario_id ? (int) $funcionario_id : null,
        'cliente_id' => $cliente_id_final ? (int) $cliente_id_final : null,
        'es_auditor' => $esAuditor
    ];

    $token = generateJWT($userData);

    if (!$token) {
        handleError("Error interno", "No se pudo generar el token");
    }

    // Función para construir respuesta según el rol
    function buildUserResponse($usuario, $rol)
    {
        // Procesar URL de foto para asegurar que sea accesible
        $urlFoto = $usuario['URL_FOTO'] ?? null;
        if ($urlFoto && !preg_match('/^http/', $urlFoto)) {
            // Es una ruta relativa, convertir a URL completa usando el proxy
            $scheme = (!empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off') ? 'https' : 'http';
            $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
            $scriptDir = dirname($_SERVER['SCRIPT_NAME']);
            $basePath = rtrim(str_replace('\\', '/', $scriptDir), '/');
            $urlFoto = $scheme . '://' . $host . $basePath . '/ver_imagen.php?ruta=' . $urlFoto;
        }

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
            "funcionario_id" => $usuario['funcionario_id'] ?? null,
            "url_foto" => $urlFoto,
            "contacto_emergencia_nombre" => $usuario['CONTACTO_EMERGENCIA_NOMBRE'] ?? null,
            "contacto_emergencia_telefono" => $usuario['CONTACTO_EMERGENCIA_TELEFONO'] ?? null,
            "es_auditor" => (function ($u) {
                foreach ($u as $k => $v) {
                    if (strtoupper($k) === 'ES_AUDITOR')
                        return (int) $v;
                }
                return 0;
            })($usuario),
            "can_edit_closed_ops" => (function ($u) {
                foreach ($u as $k => $v) {
                    if (strtoupper($k) === 'CAN_EDIT_CLOSED_OPS')
                        return (int) $v;
                }
                return 0;
            })($usuario),
        ];

        // Solo admin/gerente/rh ven datos sensibles
        if (in_array($rol, ['admin', 'gerente', 'rh'])) {
            $response['fecha_contratacion'] = $usuario['FECHA_CONTRATACION'] ?? null;
            $response['id_posicion'] = $usuario['ID_POSICION'] ?? null;
            $response['id_departamento'] = $usuario['ID_DEPARTAMENTO'] ?? null;
            $response['salario'] = $usuario['SALARIO'] ?? null;
        }

        return $response;
    }

    sendJsonResponse([
        "success" => true,
        "message" => "Inicio de sesión exitoso",
        "data" => buildUserResponse($usuario, $usuario['TIPO_ROL']),
        "token" => $token,
        "token_type" => "Bearer",
        "expires_in" => JWT_EXPIRATION_TIME,
        "expires_at" => date('Y-m-d H:i:s', time() + JWT_EXPIRATION_TIME)
    ]);
} catch (Exception $e) {
    handleError("Error del servidor", [
        "message" => $e->getMessage(),
        "line" => $e->getLine()
    ]);
} catch (Error $e) {
    handleError("Error fatal", [
        "message" => $e->getMessage(),
        "line" => $e->getLine()
    ]);
}

handleError("Error desconocido", "El script terminó sin generar respuesta");
