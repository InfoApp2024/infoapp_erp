<?php
// listar_usuarios.php - Versión mejorada

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

// Validar que la función existe antes de llamarla para evitar errores fatales (seguridad)
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
} else {
    header("Access-Control-Allow-Origin: *");
    header("Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS");
    header("Access-Control-Allow-Headers: Content-Type, Authorization, X-Requested-With, User-ID");
    header("Content-Type: application/json; charset=utf-8");
}

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/listar_usuarios.php', 'list_users');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    // Parámetros
    $id = isset($_GET['id']) ? intval($_GET['id']) : null;
    $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 10;
    $search = isset($_GET['search']) ? trim($_GET['search']) : null;
    $rol_filter = isset($_GET['rol']) ? trim($_GET['rol']) : null;
    $estado_filter = isset($_GET['estado']) ? trim($_GET['estado']) : null;

    if ($page < 1)
        $page = 1;
    if ($limit < 1 || $limit > 100)
        $limit = 10;

    $offset = ($page - 1) * $limit;

    // Verificar permisos - incluir roles que reconocen como admin
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($currentUser['rol'], $rolesAdmin);

    // 🔑 AQUÍ ES LA CLAVE:
    // Si NO hay parámetro ?id, LISTAR TODOS (incluso sin ser admin)
    // Si hay ?id, retornar UN usuario

    if ($id) {
        // OBTENER UN USUARIO ESPECÍFICO
        $sql = "SELECT * FROM usuarios WHERE id = ? LIMIT 1";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $id);
        $stmt->execute();
        $resultado = $stmt->get_result();

        if ($resultado->num_rows === 0) {
            sendJsonResponse(errorResponse('Usuario no encontrado'), 404);
        }

        $usuario = $resultado->fetch_assoc();

        // Validar permisos: solo admin puede ver otros usuarios
        if (!$esAdmin && $usuario['id'] != $currentUser['id']) {
            sendJsonResponse(errorResponse('No tienes permiso para ver este usuario'), 403);
        }

        $userResponse = buildUserResponse($usuario, $currentUser['rol']);

        sendJsonResponse([
            'success' => true,
            'message' => 'Usuario obtenido exitosamente',
            'data' => $userResponse
        ]);
    } else {
        // LISTAR TODOS (permitir a todos, no solo admin)

        // Construir WHERE clause
        $whereConditions = ["1=1"];
        $params = [];
        $types = "";

        // Por defecto, excluir clientes de los listados generales (listas de selección, etc.)
        // Solo incluirlos si se pide explícitamente via ?rol=cliente o ?include_clients=1
        $includeClients = (isset($_GET['include_clients']) && $_GET['include_clients'] === '1') || ($rol_filter === 'cliente');

        if (!$includeClients && !$rol_filter) {
            $whereConditions[] = "TIPO_ROL != 'cliente'";
        }

        if ($search) {
            $whereConditions[] = "(NOMBRE_USER LIKE ? OR NOMBRE_CLIENTE LIKE ? OR CORREO LIKE ? OR TELEFONO LIKE ?)";
            $searchPattern = "%$search%";
            $params = array_merge($params, [$searchPattern, $searchPattern, $searchPattern, $searchPattern]);
            $types .= "ssss";
        }

        if ($rol_filter) {
            $whereConditions[] = "TIPO_ROL = ?";
            $params[] = $rol_filter;
            $types .= "s";
        }

        if ($estado_filter) {
            $whereConditions[] = "ESTADO_USER = ?";
            $params[] = $estado_filter;
            $types .= "s";
        }

        $whereClause = implode(" AND ", $whereConditions);

        // Contar total
        $sqlCount = "SELECT COUNT(*) as total FROM usuarios WHERE $whereClause";
        $stmtCount = $conn->prepare($sqlCount);

        if ($params) {
            $stmtCount->bind_param($types, ...$params);
        }

        $stmtCount->execute();
        $countResult = $stmtCount->get_result()->fetch_assoc();
        $totalRecords = $countResult['total'];
        $totalPages = ceil($totalRecords / $limit);

        // Obtener registros
        $sql = "SELECT * FROM usuarios WHERE $whereClause ORDER BY id DESC LIMIT ? OFFSET ?";
        $stmt = $conn->prepare($sql);

        $params[] = $limit;
        $params[] = $offset;
        $types .= "ii";

        $stmt->bind_param($types, ...$params);
        $stmt->execute();
        $resultado = $stmt->get_result();
        $usuarios = [];

        while ($usuario = $resultado->fetch_assoc()) {
            $usuarios[] = buildUserResponse($usuario, $currentUser['rol']);
        }

        sendJsonResponse([
            'success' => true,
            'message' => 'Usuarios obtenidos exitosamente',
            'data' => $usuarios,
            'pagination' => [
                'page' => $page,
                'limit' => $limit,
                'total' => $totalRecords,
                'total_pages' => $totalPages,
                'has_next' => $page < $totalPages,
                'has_prev' => $page > 1,
                'usuario_actual' => $currentUser['usuario'],
                'rol_actual' => $currentUser['rol'],
                'es_admin' => $esAdmin
            ]
        ]);
    }
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}

function buildUserResponse($usuario, $rol)
{
    $rolesAdmin = ['admin', 'administrador', 'gerente', 'rh'];
    $esAdmin = in_array($rol, $rolesAdmin);

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

    // Solo admin ve datos sensibles
    if ($esAdmin) {
        $response['fecha_contratacion'] = $usuario['FECHA_CONTRATACION'] ?? null;
        $response['id_posicion'] = $usuario['ID_POSICION'] ?? null;
        $response['id_departamento'] = $usuario['ID_DEPARTAMENTO'] ?? null;
        $response['salario'] = $usuario['SALARIO'] ?? null;
        $response['id_especialidad'] = $usuario['ID_ESPECIALIDAD'] ?? null;
    }

    return $response;
}
