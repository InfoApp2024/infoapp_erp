<?php
// backend/servicio/listar_servicios_debug.php
// Versión con logging detallado para diagnosticar lentitud

require_once '../login/auth_middleware.php';

// Función para logging de tiempo
function logTime($label)
{
    static $start = null;
    static $last = null;

    if ($start === null) {
        $start = microtime(true);
        $last = $start;
        error_log("⏱️  INICIO: $label");
        return;
    }

    $now = microtime(true);
    $total = ($now - $start) * 1000;
    $delta = ($now - $last) * 1000;
    $last = $now;

    error_log(sprintf("⏱️  [+%.2fms | Total: %.2fms] %s", $delta, $total, $label));
}

try {
    logTime("START");

    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();
    logTime("Auth completado");

    // ✅ NUEVO: Obtener usuario_id y rol
    $usuario_id = intval($currentUser['id'] ?? 0);
    $rol = strtolower($currentUser['rol'] ?? 'user');

    // PASO 2: Log de acceso
    logAccess($currentUser, '/listar_servicios.php', 'view_services');
    logTime("Log access completado");

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';
    logTime("Conexión BD establecida");

    // Parámetros
    $pagina = isset($_GET['pagina']) ? max(1, (int) $_GET['pagina']) : 1;
    $limite = isset($_GET['limite']) ? min(100, max(1, (int) $_GET['limite'])) : 20;
    $buscar = isset($_GET['buscar']) ? trim($_GET['buscar']) : '';
    $estado = isset($_GET['estado']) ? trim($_GET['estado']) : '';
    $tipo = isset($_GET['tipo']) ? trim($_GET['tipo']) : '';
    $mis_servicios = (isset($_GET['mis_servicios']) && $_GET['mis_servicios'] === 'true') ? true : false;
    $offset = ($pagina - 1) * $limite;
    $finalizados = isset($_GET['finalizados']) ? $_GET['finalizados'] : 'false';

    if (!empty($buscar) && !isset($_GET['finalizados'])) {
        $finalizados = 'all';
    }

    logTime("Parámetros procesados");

    // Construir WHERE clause
    $whereConditions = ["1=1"];
    $params = [];
    $types = "";

    if (!empty($buscar)) {
        $whereConditions[] = "(
            s.orden_cliente LIKE ? OR 
            s.o_servicio LIKE ? OR 
            s.nombre_emp LIKE ? OR 
            s.placa LIKE ? OR
            eq.nombre LIKE ?
        )";
        $searchTerm = "%$buscar%";
        $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm]);
        $types .= "sssss";
    }

    if (!empty($estado)) {
        $whereConditions[] = "e.nombre_estado = ?";
        $params[] = $estado;
        $types .= "s";
    }

    if (!empty($tipo)) {
        $whereConditions[] = "s.tipo_mantenimiento = ?";
        $params[] = $tipo;
        $types .= "s";
    }

    $aplicar_filtro_responsable = false;
    if ($rol !== 'administrador') {
        $aplicar_filtro_responsable = true;
    } elseif ($rol === 'administrador' && $mis_servicios) {
        $aplicar_filtro_responsable = true;
    }

    if ($aplicar_filtro_responsable && $usuario_id > 0) {
        $whereConditions[] = "s.responsable_id = ?";
        $params[] = $usuario_id;
        $types .= "i";
    }

    if ($finalizados === 'true') {
        $whereConditions[] = "s.es_finalizado = 1";
    } elseif ($finalizados === 'false') {
        $whereConditions[] = "s.es_finalizado = 0";
    }

    $whereClause = "WHERE " . implode(" AND ", $whereConditions);
    logTime("WHERE clause construido");

    // Query COUNT
    if (empty($buscar)) {
        $sqlTotal = "SELECT COUNT(*) as total FROM servicios s $whereClause";
    } else {
        $sqlTotal = "SELECT COUNT(*) as total
                FROM servicios s
                LEFT JOIN estados_proceso e ON s.estado = e.id
                LEFT JOIN funcionario f ON s.autorizado_por = f.id
                LEFT JOIN equipos eq ON s.id_equipo = eq.id
                LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                $whereClause";
    }

    $stmtTotal = $conn->prepare($sqlTotal);
    if (!empty($params)) {
        $stmtTotal->bind_param($types, ...$params);
    }

    logTime("Query COUNT preparado");

    if (!$stmtTotal->execute()) {
        throw new Exception("Error ejecutando query de total: " . $stmtTotal->error);
    }

    logTime("Query COUNT ejecutado");

    $resultTotal = $stmtTotal->get_result();
    $totalRegistros = $resultTotal->fetch_assoc()['total'];
    $totalPaginas = ceil($totalRegistros / $limite);

    logTime("Total registros obtenido: $totalRegistros");

    // Query principal - SIMPLIFICADA para debug
    $sqlServicios = "SELECT s.id, s.o_servicio, s.orden_cliente, s.estado,
                     e.nombre_estado, e.color as estado_color
                     FROM servicios s
                     LEFT JOIN estados_proceso e ON s.estado = e.id
                     $whereClause
                     ORDER BY s.o_servicio DESC
                     LIMIT ? OFFSET ?";

    $stmt = $conn->prepare($sqlServicios);
    if (!empty($params)) {
        $allParams = array_merge($params, [$limite, $offset]);
        $allTypes = $types . "ii";
        $stmt->bind_param($allTypes, ...$allParams);
    } else {
        $stmt->bind_param("ii", $limite, $offset);
    }

    logTime("Query principal preparado");

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query principal: " . $stmt->error);
    }

    logTime("Query principal ejecutado");

    $result = $stmt->get_result();
    $servicios = [];

    while ($row = $result->fetch_assoc()) {
        $servicios[] = [
            'id' => (int) $row['id'],
            'o_servicio' => (int) $row['o_servicio'],
            'orden_cliente' => $row['orden_cliente'],
            'estado' => (int) $row['estado'],
            'estado_nombre' => $row['nombre_estado'] ?? 'Sin estado',
            'estado_color' => $row['estado_color'] ?? '#808080'
        ];
    }

    logTime("Datos procesados: " . count($servicios) . " servicios");

    $response = [
        'success' => true,
        'data' => [
            'servicios' => $servicios,
            'paginacion' => [
                'pagina_actual' => $pagina,
                'limite' => $limite,
                'total_registros' => (int) $totalRegistros,
                'total_paginas' => (int) $totalPaginas,
                'tiene_siguiente' => $pagina < $totalPaginas,
                'tiene_anterior' => $pagina > 1,
                'servicios_en_pagina' => count($servicios)
            ]
        ],
        'mensaje' => "Página $pagina de $totalPaginas ($totalRegistros servicios total)"
    ];

    logTime("Response preparado");

    sendJsonResponse($response);

    logTime("Response enviado");

} catch (Exception $e) {
    logTime("ERROR: " . $e->getMessage());
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>