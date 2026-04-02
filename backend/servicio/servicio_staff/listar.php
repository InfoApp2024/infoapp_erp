<?php

/**
 * GET /servicio_staff/listar.php?servicio_id=154
 * 
 * Endpoint para obtener usuarios asignados a un servicio
 * VERSIÓN CORREGIDA - Usa nombre_emp de tabla servicios
 */

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_FILE', __DIR__ . '/debug_listar_v3.log');

function debug_log($msg)
{
    $time = date('Y-m-d H:i:s');
    $log = "[$time] $msg\n";
    file_put_contents(DEBUG_FILE, $log, FILE_APPEND);
}

debug_log("========================================");
debug_log("🆕 NUEVA SOLICITUD A LISTAR.PHP v3");
debug_log("========================================");

header('Content-Type: application/json; charset=utf-8');

try {
    debug_log("🔐 Iniciando autenticación...");

    $auth_file = '../../login/auth_middleware.php';
    if (!file_exists($auth_file)) {
        debug_log("❌ ERROR: No existe $auth_file");
        throw new Exception("Auth middleware no encontrado");
    }

    require_once $auth_file;

    $currentUser = requireAuth();
    debug_log("✅ Autenticado: usuario=" . $currentUser['usuario'] . ", id=" . $currentUser['id']);

    logAccess($currentUser, '/servicio/servicio_staff/listar.php', 'view_service_staff');

    // Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        debug_log("❌ Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    debug_log("✅ Método GET validado");

    // Conectar a BD
    debug_log("🔗 Conectando a base de datos...");
    require '../../conexion.php';

    if (!isset($conn) || $conn->connect_error) {
        debug_log("❌ ERROR de conexión: " . ($conn->connect_error ?? 'unknown'));
        throw new Exception("Error de conexión a BD");
    }
    debug_log("✅ Conexión a BD establecida");

    // Obtener y validar servicio_id
    debug_log("📥 Obteniendo parámetro servicio_id...");
    $servicio_id = isset($_GET['servicio_id']) ? intval($_GET['servicio_id']) : 0;
    debug_log("   servicio_id: $servicio_id");

    if (!$servicio_id || $servicio_id <= 0) {
        debug_log("❌ servicio_id inválido");
        sendJsonResponse(errorResponse('servicio_id inválido'), 400);
    }
    debug_log("✅ servicio_id válido");

    // ✅ CORREGIDO: Usar nombre_emp en lugar de nombre
    debug_log("🔍 Verificando que servicio existe...");
    $sqlService = "SELECT id, nombre_emp FROM servicios WHERE id = ? LIMIT 1";
    debug_log("   Query: $sqlService");

    $stmtService = $conn->prepare($sqlService);
    if (!$stmtService) {
        debug_log("❌ ERROR prepare(): " . $conn->error);
        throw new Exception("Error preparando query: " . $conn->error);
    }

    $stmtService->bind_param('i', $servicio_id);
    $stmtService->execute();
    $resultService = $stmtService->get_result();

    if ($resultService->num_rows === 0) {
        debug_log("❌ Servicio no encontrado: ID $servicio_id");
        sendJsonResponse(errorResponse("Servicio no encontrado"), 404);
    }

    $servicio = $resultService->fetch_assoc();
    debug_log("✅ Servicio encontrado");

    $servicio_nombre = $servicio['nombre_emp'] ?? 'Sin nombre';
    $stmtService->close();
    debug_log("   Nombre: $servicio_nombre");

    // Query principal - Obtener usuarios
    debug_log("📋 Ejecutando query de usuarios...");

    $sql = "
        SELECT 
            u.id as usuario_id,
            u.NOMBRE_USER as nombre_usuario,
            u.NOMBRE_CLIENTE as apellido_usuario,
            u.CORREO as correo,
            u.TELEFONO as telefono,
            u.URL_FOTO as foto,
            CASE WHEN u.ESTADO_USER = 'activo' THEN 1 ELSE 0 END as activo,
            u.CODIGO_STAFF as codigo,
            u.ID_POSICION as pos_id,
            u.ID_DEPARTAMENTO as dep_id,
            ss.id as pivot_id,
            ss.created_at as fecha_asignacion,
            -- Campos de Operación (NUEVO)
            ss.operacion_id,
            o.descripcion as operacion_nombre,
            o.is_master
        FROM servicio_staff ss
        INNER JOIN usuarios u ON ss.staff_id = u.id
        LEFT JOIN operaciones o ON ss.operacion_id = o.id
        WHERE ss.servicio_id = ?
        ORDER BY u.NOMBRE_USER ASC
    ";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        debug_log("❌ ERROR prepare(): " . $conn->error);
        throw new Exception('Error preparando query: ' . $conn->error);
    }

    $stmt->bind_param('i', $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();

    debug_log("✅ Query ejecutada");

    // Procesar resultados
    debug_log("🔄 Procesando resultados...");
    $usuarios = [];
    $row_count = 0;

    while ($row = $result->fetch_assoc()) {
        $row_count++;
        $usuarios[] = [
            'usuario_id' => intval($row['usuario_id']),
            'nombre' => $row['nombre_usuario'] ?? '',
            'apellido' => $row['apellido_usuario'] ?? '',
            'correo' => $row['correo'] ?? '',
            'telefono' => $row['telefono'],
            'foto' => $row['foto'],
            'activo' => boolval($row['activo']),
            'codigo_staff' => $row['codigo'],
            'posicion_id' => $row['pos_id'],
            'departamento_id' => $row['dep_id'],
            'servicio_id' => $servicio_id,
            'asignado_en' => $row['fecha_asignacion'],
            // Campos de Operación
            'operacion_id' => isset($row['operacion_id']) ? (int) $row['operacion_id'] : null,
            'operacion_nombre' => $row['operacion_nombre'] ?? null,
            'is_master' => isset($row['is_master']) ? (bool) $row['is_master'] : false
        ];
    }

    debug_log("✅ Total de usuarios: $row_count");
    $stmt->close();

    // Preparar respuesta
    debug_log("📤 Preparando respuesta...");

    $response = [
        'success' => true,
        'message' => 'Usuarios del servicio obtenidos',
        'data' => [
            'servicio_id' => $servicio_id,
            'servicio_nombre' => $servicio_nombre,
            'usuarios' => $usuarios,
            'total' => count($usuarios)
        ],
        'consultado_por' => $currentUser['usuario']
    ];

    debug_log("✅ Respuesta enviada con " . count($usuarios) . " usuarios");
    sendJsonResponse($response);
} catch (Exception $e) {
    debug_log("🔴 EXCEPTION: " . $e->getMessage());
    debug_log("   Archivo: " . $e->getFile());
    debug_log("   Línea: " . $e->getLine());
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
} finally {
    if (isset($conn)) {
        $conn->close();
        debug_log("🔌 Conexión cerrada");
    }
    debug_log("========================================\n");
}
