<?php
// listar_firmas.php - Protegido con JWT
// FINAL: Staff de usuarios, Funcionario de funcionario

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_listar_firmas.txt');

function log_debug($msg) {
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("ERROR FATAL: " . $error['message']);
        log_debug("Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function($e) {
    log_debug("EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("NUEVA REQUEST LISTAR FIRMAS");
log_debug("========================================");
log_debug("IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("auth_middleware cargado");
    
    $currentUser = requireAuth();
    log_debug("Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    
    logAccess($currentUser, '/firma/listar_firmas.php', 'list_firmas');
    log_debug("Acceso registrado");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    log_debug("Requiriendo conexión...");
    require '../conexion.php';
    log_debug("conexion.php cargado");

    // Parámetros de filtrado y paginación
    $id_servicio = isset($_GET['id_servicio']) ? intval($_GET['id_servicio']) : null;
    $fecha_desde = isset($_GET['fecha_desde']) ? $_GET['fecha_desde'] : null;
    $fecha_hasta = isset($_GET['fecha_hasta']) ? $_GET['fecha_hasta'] : null;
    $limite = isset($_GET['limite']) ? intval($_GET['limite']) : 50;
    $offset = isset($_GET['offset']) ? intval($_GET['offset']) : 0;

    log_debug("Parámetros recibidos:");
    log_debug("   id_servicio: " . ($id_servicio ?? 'NULL'));
    log_debug("   fecha_desde: " . ($fecha_desde ?? 'NULL'));
    log_debug("   fecha_hasta: " . ($fecha_hasta ?? 'NULL'));
    log_debug("   limite: $limite");
    log_debug("   offset: $offset");

    // Construir query con filtros dinámicos
    // FINAL: Staff de usuarios, Funcionario de funcionario
    $sql = "SELECT 
                f.id,
                f.id_servicio,
                f.id_staff_entrega,
                f.id_funcionario_recibe,
                f.nota_entrega,
                f.nota_recepcion,
                f.participantes_servicio,
                f.created_at,
                f.updated_at,
                s.o_servicio,
                s.orden_cliente,
                s.tipo_mantenimiento,
                e.placa,
                e.nombre_empresa,
                ue.NOMBRE_USER as staff_nombre,
                ue.correo as staff_email,
                fun.nombre as funcionario_nombre,
                fun.cargo as funcionario_cargo,
                fun.empresa as funcionario_empresa
            FROM firmas f
            INNER JOIN servicios s ON f.id_servicio = s.id
            INNER JOIN equipos e ON s.id_equipo = e.id
            LEFT JOIN usuarios ue ON f.id_staff_entrega = ue.id
            LEFT JOIN funcionario fun ON f.id_funcionario_recibe = fun.id
            WHERE 1=1";

    $params = [];
    $types = "";

    // Filtro por servicio
    if ($id_servicio !== null) {
        $sql .= " AND f.id_servicio = ?";
        $params[] = $id_servicio;
        $types .= "i";
        log_debug("Filtro por id_servicio aplicado: $id_servicio");
    }

    // Filtro por fecha desde
    if ($fecha_desde !== null) {
        $sql .= " AND DATE(f.created_at) >= ?";
        $params[] = $fecha_desde;
        $types .= "s";
        log_debug("Filtro por fecha_desde aplicado: $fecha_desde");
    }

    // Filtro por fecha hasta
    if ($fecha_hasta !== null) {
        $sql .= " AND DATE(f.created_at) <= ?";
        $params[] = $fecha_hasta;
        $types .= "s";
        log_debug("Filtro por fecha_hasta aplicado: $fecha_hasta");
    }

    // Ordenar y paginar
    $sql .= " ORDER BY f.created_at DESC LIMIT ? OFFSET ?";
    $params[] = $limite;
    $params[] = $offset;
    $types .= "ii";

    log_debug("Query construido");
    log_debug("Preparando statement...");

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        log_debug("ERROR PREPARE: " . $conn->error);
        throw new Exception('Error prepare: ' . $conn->error);
    }
    log_debug("Statement preparado correctamente");

    // Bind params dinámicos
    if (!empty($params)) {
        log_debug("Binding " . count($params) . " params con tipos: $types");
        $stmt->bind_param($types, ...$params);
    }

    log_debug("Ejecutando query...");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $firmas = [];
    $count = 0;
    
    while ($row = $result->fetch_assoc()) {
        $firmas[] = [
            'id' => (int)$row['id'],
            'idServicio' => (int)$row['id_servicio'],
            'oServicio' => (int)$row['o_servicio'],
            'numeroServicioFormateado' => sprintf('#%04d', $row['o_servicio']),
            'ordenCliente' => $row['orden_cliente'],
            'tipoMantenimiento' => $row['tipo_mantenimiento'],
            'placa' => $row['placa'],
            'nombreEmpresa' => $row['nombre_empresa'],
            'idStaffEntrega' => (int)$row['id_staff_entrega'],
            'staffNombre' => $row['staff_nombre'],
            'staffEmail' => $row['staff_email'],
            'idFuncionarioRecibe' => (int)$row['id_funcionario_recibe'],
            'funcionarioNombre' => $row['funcionario_nombre'],
            'funcionarioCargo' => $row['funcionario_cargo'],
            'funcionarioEmpresa' => $row['funcionario_empresa'],
            'notaEntrega' => $row['nota_entrega'],
            'notaRecepcion' => $row['nota_recepcion'],
            'participantesServicio' => $row['participantes_servicio'],
            'createdAt' => $row['created_at'],
            'updatedAt' => $row['updated_at']
        ];
        $count++;
    }

    log_debug("Firmas encontradas: $count");

    // Obtener total de registros (sin límite)
    $sql_count = "SELECT COUNT(*) as total FROM firmas f WHERE 1=1";
    
    $params_count = [];
    $types_count = "";

    if ($id_servicio !== null) {
        $sql_count .= " AND f.id_servicio = ?";
        $params_count[] = $id_servicio;
        $types_count .= "i";
    }

    if ($fecha_desde !== null) {
        $sql_count .= " AND DATE(f.created_at) >= ?";
        $params_count[] = $fecha_desde;
        $types_count .= "s";
    }

    if ($fecha_hasta !== null) {
        $sql_count .= " AND DATE(f.created_at) <= ?";
        $params_count[] = $fecha_hasta;
        $types_count .= "s";
    }

    $stmt_count = $conn->prepare($sql_count);
    if (!empty($params_count)) {
        $stmt_count->bind_param($types_count, ...$params_count);
    }
    $stmt_count->execute();
    $result_count = $stmt_count->get_result();
    $total_registros = $result_count->fetch_assoc()['total'];

    log_debug("Total de registros: $total_registros");

    $response_data = [
        'success' => true,
        'data' => $firmas,
        'pagination' => [
            'total' => (int)$total_registros,
            'limite' => $limite,
            'offset' => $offset,
            'count' => $count
        ]
    ];

    log_debug("Preparando respuesta JSON...");
    log_debug("Respuesta preparada (size: " . strlen(json_encode($response_data)) . " bytes)");
    
    sendJsonResponse($response_data, 200);
    
    log_debug("sendJsonResponse ejecutado");

} catch (Exception $e) {
    log_debug("EXCEPTION CAPTURADA");
    log_debug("Mensaje: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile());
    log_debug("Línea: " . $e->getLine());
    log_debug("Trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt)) {
        $stmt->close();
        log_debug("Statement cerrado");
    }
    if (isset($stmt_count)) {
        $stmt_count->close();
        log_debug("Statement count cerrado");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("REQUEST FINALIZADA");
    log_debug("========================================\n");
}
?>