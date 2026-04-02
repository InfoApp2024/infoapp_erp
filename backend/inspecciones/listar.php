<?php
// listar.php - Listar inspecciones con filtros y paginación - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/listar.php', 'view_inspections');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    // Parámetros de paginación
    $pagina = isset($_GET['pagina']) ? max(1, (int) $_GET['pagina']) : 1;
    $limite = isset($_GET['limite']) ? min(100, max(1, (int) $_GET['limite'])) : 20;
    $buscar = isset($_GET['buscar']) ? trim($_GET['buscar']) : '';
    $estado = isset($_GET['estado']) ? trim($_GET['estado']) : '';
    $sitio = isset($_GET['sitio']) ? trim($_GET['sitio']) : '';
    $equipo_id = isset($_GET['equipo_id']) ? (int) $_GET['equipo_id'] : null;
    $fecha_desde = isset($_GET['fecha_desde']) ? trim($_GET['fecha_desde']) : '';
    $fecha_hasta = isset($_GET['fecha_hasta']) ? trim($_GET['fecha_hasta']) : '';

    $offset = ($pagina - 1) * $limite;

    // Construir WHERE clause
    $whereConditions = ["i.deleted_at IS NULL"]; // Solo inspecciones no eliminadas
    $params = [];
    $types = "";

    // Filtro por búsqueda
    if (!empty($buscar)) {
        $whereConditions[] = "(
            i.o_inspe LIKE ? OR 
            eq.nombre LIKE ? OR 
            eq.placa LIKE ?
        )";
        $searchTerm = "%$buscar%";
        $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm]);
        $types .= "sss";
    }

    // Filtro por estado
    if (!empty($estado)) {
        $whereConditions[] = "e.nombre_estado = ?";
        $params[] = $estado;
        $types .= "s";
    }

    // Filtro por sitio
    if (!empty($sitio)) {
        $whereConditions[] = "i.sitio = ?";
        $params[] = $sitio;
        $types .= "s";
    }

    // Filtro por equipo
    if ($equipo_id) {
        $whereConditions[] = "i.equipo_id = ?";
        $params[] = $equipo_id;
        $types .= "i";
    }

    // Filtro por rango de fechas
    if (!empty($fecha_desde)) {
        $whereConditions[] = "i.fecha_inspe >= ?";
        $params[] = $fecha_desde;
        $types .= "s";
    }

    if (!empty($fecha_hasta)) {
        $whereConditions[] = "i.fecha_inspe <= ?";
        $params[] = $fecha_hasta;
        $types .= "s";
    }

    // 🔒 SEGURIDAD: Filtrado obligatorio para rol cliente
    if ($currentUser['rol'] === 'cliente') {
        if (!isset($currentUser['cliente_id']) || empty($currentUser['cliente_id'])) {
            throw new Exception("Error de seguridad: Usuario cliente sin cliente_id asignado.");
        }
        $whereConditions[] = "eq.cliente_id = ?";
        $params[] = $currentUser['cliente_id'];
        $types .= "i";
    }

    $whereClause = "WHERE " . implode(" AND ", $whereConditions);

    // Query principal con JOINs optimizados
    $sqlInspecciones = "SELECT 
                i.id,
                i.o_inspe,
                i.estado_id,
                i.sitio,
                i.fecha_inspe,
                i.equipo_id,
                i.created_at,
                i.updated_at,
                i.created_by,
                i.updated_by,
                
                e.nombre_estado as estado_nombre,
                e.color as estado_color,
                (CASE WHEN e.id = (SELECT MAX(id) FROM estados_proceso WHERE modulo = e.modulo) THEN 1 ELSE 0 END) as es_final,
                
                eq.nombre as equipo_nombre,
                eq.placa as equipo_placa,
                eq.modelo as equipo_modelo,
                eq.marca as equipo_marca,
                eq.nombre_empresa as equipo_empresa,
                
                u_creador.NOMBRE_USER as creado_por_nombre,
                u_actualizo.NOMBRE_USER as actualizado_por_nombre,
                
                -- Contar inspectores
                COALESCE(inspectores_count.cantidad, 0) as total_inspectores,
                
                -- Contar sistemas
                COALESCE(sistemas_count.cantidad, 0) as total_sistemas,
                
                -- Contar actividades
                COALESCE(actividades_count.cantidad, 0) as total_actividades,
                
                -- Contar actividades autorizadas
                COALESCE(actividades_autorizadas_count.cantidad, 0) as actividades_autorizadas,
                
                -- Contar actividades eliminadas
                COALESCE(actividades_eliminadas_count.cantidad, 0) as actividades_eliminadas,
                
                -- Contar actividades vinculadas a servicios
                COALESCE(actividades_vinculadas_count.cantidad, 0) as actividades_vinculadas,
                
                -- Contar evidencias
                COALESCE(evidencias_count.cantidad, 0) as total_evidencias
                
            FROM inspecciones i
            LEFT JOIN estados_proceso e ON i.estado_id = e.id
            LEFT JOIN equipos eq ON i.equipo_id = eq.id
            LEFT JOIN usuarios u_creador ON i.created_by = u_creador.id
            LEFT JOIN usuarios u_actualizo ON i.updated_by = u_actualizo.id
            
            -- Agregaciones optimizadas
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_inspectores 
                GROUP BY inspeccion_id
            ) inspectores_count ON inspectores_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_sistemas 
                GROUP BY inspeccion_id
            ) sistemas_count ON sistemas_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_actividades 
                WHERE deleted_at IS NULL
                GROUP BY inspeccion_id
            ) actividades_count ON actividades_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_actividades 
                WHERE autorizada = 1 AND servicio_id IS NULL AND deleted_at IS NULL
                GROUP BY inspeccion_id
            ) actividades_autorizadas_count ON actividades_autorizadas_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_actividades 
                WHERE deleted_at IS NOT NULL
                GROUP BY inspeccion_id
            ) actividades_eliminadas_count ON actividades_eliminadas_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_actividades 
                WHERE servicio_id IS NOT NULL AND deleted_at IS NULL
                GROUP BY inspeccion_id
            ) actividades_vinculadas_count ON actividades_vinculadas_count.inspeccion_id = i.id
            
            LEFT JOIN (
                SELECT inspeccion_id, COUNT(*) as cantidad 
                FROM inspecciones_evidencias 
                GROUP BY inspeccion_id
            ) evidencias_count ON evidencias_count.inspeccion_id = i.id
            
            $whereClause
            ORDER BY i.id DESC
            LIMIT ? OFFSET ?";

    // Query para total
    $sqlTotal = "SELECT COUNT(*) as total
                FROM inspecciones i
                LEFT JOIN estados_proceso e ON i.estado_id = e.id
                LEFT JOIN equipos eq ON i.equipo_id = eq.id
                $whereClause";

    // Ejecutar query principal
    $stmt = $conn->prepare($sqlInspecciones);
    if (!empty($params)) {
        $allParams = array_merge($params, [$limite, $offset]);
        $allTypes = $types . "ii";
        $stmt->bind_param($allTypes, ...$allParams);
    } else {
        $stmt->bind_param("ii", $limite, $offset);
    }

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query principal: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $inspecciones = [];

    while ($row = $result->fetch_assoc()) {
        $inspeccion = [
            'id' => (int) $row['id'],
            'o_inspe' => $row['o_inspe'],
            'estado_id' => (int) $row['estado_id'],
            'estado_nombre' => $row['estado_nombre'] ?? 'Sin estado',
            'estado_color' => $row['estado_color'] ?? '#808080',
            'es_final' => (bool) $row['es_final'],
            'sitio' => $row['sitio'],
            'fecha_inspe' => $row['fecha_inspe'],
            'equipo_id' => (int) $row['equipo_id'],
            'equipo_nombre' => $row['equipo_nombre'] ?? 'Equipo no encontrado',
            'equipo_placa' => $row['equipo_placa'] ?? '',
            'equipo_modelo' => $row['equipo_modelo'] ?? '',
            'equipo_marca' => $row['equipo_marca'] ?? '',
            'equipo_empresa' => $row['equipo_empresa'] ?? '',
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
            'creado_por_nombre' => $row['creado_por_nombre'] ?? 'Desconocido',
            'actualizado_por_nombre' => $row['actualizado_por_nombre'] ?? 'Desconocido',
            'total_inspectores' => (int) $row['total_inspectores'],
            'total_sistemas' => (int) $row['total_sistemas'],
            'total_actividades' => (int) $row['total_actividades'],
            'actividades_autorizadas' => (int) $row['actividades_autorizadas'],
            'actividades_eliminadas' => (int) $row['actividades_eliminadas'],
            'actividades_vinculadas' => (int) $row['actividades_vinculadas'],
            'total_evidencias' => (int) $row['total_evidencias']
        ];

        $inspecciones[] = $inspeccion;
    }

    // Ejecutar query de total
    $stmtTotal = $conn->prepare($sqlTotal);
    if (!empty($params)) {
        $stmtTotal->bind_param($types, ...$params);
    }

    if (!$stmtTotal->execute()) {
        throw new Exception("Error ejecutando query de total: " . $stmtTotal->error);
    }

    $resultTotal = $stmtTotal->get_result();
    $totalRegistros = $resultTotal->fetch_assoc()['total'];
    $totalPaginas = ceil($totalRegistros / $limite);

    // Respuesta
    sendJsonResponse([
        'success' => true,
        'data' => [
            'inspecciones' => $inspecciones,
            'paginacion' => [
                'pagina_actual' => $pagina,
                'limite' => $limite,
                'total_registros' => (int) $totalRegistros,
                'total_paginas' => (int) $totalPaginas,
                'tiene_siguiente' => $pagina < $totalPaginas,
                'tiene_anterior' => $pagina > 1,
                'inspecciones_en_pagina' => count($inspecciones)
            ]
        ],
        'mensaje' => "Página $pagina de $totalPaginas ($totalRegistros inspecciones total)",
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol']
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>