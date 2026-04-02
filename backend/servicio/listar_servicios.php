<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // ✅ NUEVO: Obtener usuario_id y rol
    $usuario_id = intval($currentUser['id'] ?? 0);
    $rol = strtolower($currentUser['rol'] ?? 'user');

    // PASO 2: Log de acceso
    logAccess($currentUser, '/listar_servicios.php', 'view_services');

    // PASO 3: Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // PASO 4: Conexión a BD
    require '../conexion.php';

    // Parámetros con valores por defecto
    $pagina = isset($_GET['pagina']) ? max(1, (int) $_GET['pagina']) : 1;
    $limite = isset($_GET['limite']) ? min(100, max(1, (int) $_GET['limite'])) : 20;
    $buscar = isset($_GET['buscar']) ? trim($_GET['buscar']) : '';
    $estado = isset($_GET['estado']) ? trim($_GET['estado']) : '';
    $tipo = isset($_GET['tipo']) ? trim($_GET['tipo']) : '';

    // ✅ NUEVO: Parámetro opcional para admins
    $mis_servicios = (isset($_GET['mis_servicios']) && $_GET['mis_servicios'] === 'true') ? true : false;

    $offset = ($pagina - 1) * $limite;

    // ✅ ROLES CON ACCESO TOTAL (ven todos los servicios por defecto)
    $rolesAdmin = ['administrador', 'admin', 'gerente'];
    $es_admin = in_array($rol, $rolesAdmin);

    // ✅ DETERMINAR SI HAY FILTRO DE VISIBILIDAD
    // - Admins/Gerentes: ven TODO, salvo que pidan explícitamente "mis_servicios"
    // - Colaboradores y otros roles: solo ven los servicios que tienen asignados
    $aplicar_filtro_responsable = false;
    if (!$es_admin) {
        $aplicar_filtro_responsable = true;
    } elseif ($es_admin && $mis_servicios) {
        $aplicar_filtro_responsable = true;
    }

    // ✅ NUEVO: Filtro "finalizados" (true/false/all)
    // - true: Solo finalizados o anulados
    // - false: Solo activos (en proceso)
    // - all / null: Todos
    $finalizados = isset($_GET['finalizados']) ? $_GET['finalizados'] : 'false'; // Por defecto solo activos

    // Si buscamos algo específico, por defecto buscamos en TODO el historial, no solo en activos
    if (!empty($buscar) && !isset($_GET['finalizados'])) {
        $finalizados = 'all';
    }

    // Construir WHERE clause
    $whereConditions = ["1=1"];
    $params = [];
    $types = "";

    // Filtro por búsqueda
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

    // Filtro por estado
    if (!empty($estado)) {
        $whereConditions[] = "e.nombre_estado = ?";
        $params[] = $estado;
        $types .= "s";
    }

    // Filtro por tipo
    if (!empty($tipo)) {
        $whereConditions[] = "s.tipo_mantenimiento = ?";
        $params[] = $tipo;
        $types .= "s";
    }

    // ✅ FILTRO DE VISIBILIDAD: responsable_id O asignado en servicio_staff
    // Chequea usuario_id (usuarios del sistema) y staff_id (técnicos del catálogo)
    if ($aplicar_filtro_responsable && $usuario_id > 0) {
        $whereConditions[] = "(
            s.responsable_id = ? OR EXISTS (
                SELECT 1 FROM servicio_staff ss
                WHERE ss.servicio_id = s.id
                  AND (ss.usuario_id = ? OR ss.staff_id = ?)
            )
        )";
        $params[] = $usuario_id;
        $params[] = $usuario_id;
        $params[] = $usuario_id;
        $types .= "iii";
    }

    // ✅ REFINADO: Filtrado basado EXCLUSIVAMENTE en balance financiero (Causación)
    // ✅ REFINADO: Filtrado basado EXCLUSIVAMENTE en balance financiero (Causación)
    if ($finalizados === 'true') {
        // Mostrar SOLO servicios que ya pasaron por gestión financiera (Causados o Facturados)
        $whereConditions[] = "TRIM(UPPER(fcs.estado_comercial_cache)) IN ('CAUSADO', 'FACTURADO')";
    } elseif ($finalizados === 'false') {
        // Mostrar SOLO servicios activos (Todo lo que NO esté causado ni facturado)
        $whereConditions[] = "(fcs.estado_comercial_cache IS NULL OR TRIM(UPPER(fcs.estado_comercial_cache)) NOT IN ('CAUSADO', 'FACTURADO'))";
    }
    // Si es 'all', no agregamos condición extra

    $whereClause = "WHERE " . implode(" AND ", $whereConditions);

    // ✅ OPTIMIZACIÓN CRÍTICA: Reemplazar subconsultas correlacionadas con LEFT JOINs
    // Las subconsultas se ejecutan para CADA fila, causando lentitud extrema
    $sqlServicios = "SELECT 
                s.id,
                -- COALESCE(notas_count.cantidad, 0) as cantidad_notas, -- REEMPLAZADO POR SUBCONSULTA
                -- CASE WHEN firmas_count.cantidad > 0 THEN 1 ELSE 0 END as tiene_firma, -- REEMPLAZADO
                -- CASE WHEN desbloqueos_count.cantidad > 0 THEN 1 ELSE 0 END as esta_desbloqueado, -- REEMPLAZADO
                s.fecha_registro,
                s.fecha_ingreso,
                s.o_servicio,
                s.orden_cliente,
                s.autorizado_por,
                s.tipo_mantenimiento,
                s.centro_costo,
                s.id_equipo,
                s.nombre_emp,
                s.placa,
                s.estado,
                s.suministraron_repuestos,
                s.fotos_confirmadas,
                s.firma_confirmada,
                s.fecha_finalizacion,
                s.anular_servicio,
                s.razon,
                s.actividad_id,
                s.responsable_id,
                
                -- Agregar nombre de la actividad y métricas
                ae.actividad as actividad_nombre,
                ae.cant_hora,
                (SELECT COUNT(*) FROM servicio_staff ss WHERE ss.servicio_id = s.id) as num_tecnicos_real,
                ae.num_tecnicos as num_tecnicos_estandar,
                st.nombre as sistema_nombre,
                
                s.cliente_id,
                cl.nombre_completo as cliente_nombre,
                
                e.nombre_estado as estado_nombre,
                e.color as estado_color,
                
                f.nombre as autorizado_por_nombre,
                f.cargo as autorizado_por_cargo,
                f.empresa as autorizado_por_empresa,
                
                eq.nombre as equipo_nombre,
                eq.modelo as equipo_modelo,
                eq.marca as equipo_marca,
                eq.codigo as equipo_codigo,
                eq.ciudad as equipo_ciudad,
                eq.planta as equipo_planta,
                eq.linea_prod as equipo_linea_prod,
                eq.nombre_empresa as equipo_empresa,

                 -- ✅ OPTIMIZACIÓN: Subconsultas correlacionadas (solo para los registros visibles)
                (SELECT COUNT(*) FROM notas n WHERE n.id_servicio = s.id) as cantidad_notas,
                (SELECT COUNT(*) FROM firmas fi WHERE fi.id_servicio = s.id) as tiene_firma_count,
                (SELECT COUNT(*) FROM servicios_desbloqueos_repuestos dr WHERE dr.servicio_id = s.id AND dr.usado = 0) as desbloqueos_count,
                fcs.estado_comercial_cache as estado_comercial
                
            FROM servicios s
            LEFT JOIN estados_proceso e ON s.estado = e.id
            LEFT JOIN funcionario f ON s.autorizado_por = f.id
            LEFT JOIN equipos eq ON s.id_equipo = eq.id
            LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
            LEFT JOIN sistemas st ON ae.sistema_id = st.id -- ✅ JOIN Sistemas
            LEFT JOIN clientes cl ON s.cliente_id = cl.id
            LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id -- ✅ JOIN Comercial
            
            -- ✅ OPTIMIZACIÓN: Eliminados los LEFT JOIN GROUP BY masivos
            $whereClause
            ORDER BY s.o_servicio DESC
            LIMIT ? OFFSET ?";

    // QUERY PARA TOTAL OPTIMIZADA
    // Si NO hay búsqueda de texto, no necesitamos los JOINS extras, PERO SÍ el de fac_control_servicios para el filtrado comercial
    if (empty($buscar)) {
        $sqlTotal = "SELECT COUNT(*) as total 
                     FROM servicios s 
                     LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
                     $whereClause";
    } else {
        // Si hay búsqueda, necesitamos los JOINS porque se busca en columnas de tablas relacionadas
        $sqlTotal = "SELECT COUNT(*) as total
                FROM servicios s
                LEFT JOIN estados_proceso e ON s.estado = e.id
                LEFT JOIN funcionario f ON s.autorizado_por = f.id
                LEFT JOIN equipos eq ON s.id_equipo = eq.id
                LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
                LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
                $whereClause";
    }

    // Ejecutar query principal
    $stmt = $conn->prepare($sqlServicios);
    if (!empty($params)) {
        $allParams = array_merge($params, [$limite, $offset]);
        $allTypes = $types . "ii";
        $stmt->bind_param($allTypes, ...$allParams);
    } else {
        $stmt->bind_param("ii", $limite, $offset);
    }

    // DEBUG SQL: Si se solicita, mostrar SQL y EXPLAIN
    /* COMENTADO PARA DIAGNÓSTICO DE TIEMPOS
    if (isset($_GET['debug_sql']) && $_GET['debug_sql'] === 'true') {
        $finalSql = $sqlServicios;
        // Simulación de parámetros en string para visualización
        // (Nota: esto es aproximado, solo para debug)

        $explainSql = "EXPLAIN " . $sqlServicios;
        $stmtExplain = $conn->prepare($explainSql);
        if (!empty($params)) {
            $allParams = array_merge($params, [$limite, $offset]);
            $allTypes = $types . "ii";
            $stmtExplain->bind_param($allTypes, ...$allParams);
        } else {
            $stmtExplain->bind_param("ii", $limite, $offset);
        }
        $stmtExplain->execute();
        $explainResult = $stmtExplain->get_result()->fetch_all(MYSQLI_ASSOC);

        echo json_encode([
            'debug' => true,
            'sql' => $sqlServicios,
            'params' => array_merge($params, [$limite, $offset]),
            'types' => $types . "ii",
            'explain' => $explainResult
        ], JSON_PRETTY_PRINT);
        exit;
    }
    */

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query principal: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $servicios = [];

    while ($row = $result->fetch_assoc()) {
        $servicio = [
            'id' => (int) $row['id'],
            'cantidad_notas' => (int) $row['cantidad_notas'], // ✅ NUEVO: Cantidad de notas
            'fecha_registro' => $row['fecha_registro'],
            'fecha_ingreso' => $row['fecha_ingreso'],
            'o_servicio' => (int) $row['o_servicio'],
            'orden_cliente' => $row['orden_cliente'],
            'autorizado_por' => (int) $row['autorizado_por'],
            'tipo_mantenimiento' => $row['tipo_mantenimiento'],
            'centro_costo' => $row['centro_costo'] ?? null,
            'cliente_id' => $row['cliente_id'] !== null ? (int) $row['cliente_id'] : null,
            'cliente_nombre' => $row['cliente_nombre'] ?? null,
            'id_equipo' => (int) $row['id_equipo'],
            'nombre_emp' => $row['nombre_emp'],
            'placa' => $row['placa'],
            'estado' => (int) $row['estado'],
            'suministraron_repuestos' => (int) $row['suministraron_repuestos'],
            'fotos_confirmadas' => (int) $row['fotos_confirmadas'],
            'firma_confirmada' => (int) $row['firma_confirmada'],
            'fecha_finalizacion' => $row['fecha_finalizacion'],
            'anular_servicio' => (int) $row['anular_servicio'],
            'razon' => $row['razon'],
            'actividad_id' => $row['actividad_id'] !== null ? (int) $row['actividad_id'] : null,

            // Agregar nombre de la actividad y métricas
            'actividad_nombre' => $row['actividad_nombre'] ?? null,
            'cant_hora' => $row['cant_hora'] !== null ? (float) $row['cant_hora'] : 0.0,
            'num_tecnicos' => $row['num_tecnicos_real'] !== null ? (int) $row['num_tecnicos_real'] : 0,
            'num_tecnicos_estandar' => $row['num_tecnicos_estandar'] !== null ? (int) $row['num_tecnicos_estandar'] : 1,
            'sistema_nombre' => $row['sistema_nombre'] ?? '',

            'estado_nombre' => $row['estado_nombre'] ?? 'Sin estado',
            'estado_color' => $row['estado_color'] ?? '#808080',
            'estado_id' => (int) $row['estado'],

            // ✅ NUEVO: Incluir responsable_id
            'responsable_id' => $row['responsable_id'] !== null ? (int) $row['responsable_id'] : null,

            'autorizado_por_nombre' => $row['autorizado_por_nombre'] ?? 'Sin autorizar',
            'autorizado_por_cargo' => $row['autorizado_por_cargo'] ?? '',
            'autorizado_por_empresa' => $row['autorizado_por_empresa'] ?? '',

            'equipo_nombre' => $row['equipo_nombre'] ?? 'Equipo no encontrado',
            'equipo_modelo' => $row['equipo_modelo'] ?? '',
            'equipo_marca' => $row['equipo_marca'] ?? '',
            'equipo_codigo' => $row['equipo_codigo'] ?? '',
            'equipo_ciudad' => $row['equipo_ciudad'] ?? '',
            'equipo_planta' => $row['equipo_planta'] ?? '',
            'equipo_linea_prod' => $row['equipo_linea_prod'] ?? '',
            'equipo_empresa' => $row['equipo_empresa'] ?? '',

            'equipo_descripcion' => ($row['equipo_nombre'] ?? 'Sin equipo') .
                (isset($row['equipo_modelo']) && $row['equipo_modelo'] ?
                    ' - ' . $row['equipo_modelo'] : '') .
                (isset($row['equipo_marca']) && $row['equipo_marca'] ?
                    ' (' . $row['equipo_marca'] . ')' : ''),
            'esta_anulado' => (int) $row['anular_servicio'] === 1,
            'esta_finalizado' => !empty($row['fecha_finalizacion']),
            'tiene_repuestos' => (int) $row['suministraron_repuestos'] === 1,
            'tiene_firma' => (int) $row['tiene_firma_count'] > 0,
            'bloqueo_repuestos' => ((int) $row['tiene_firma_count'] > 0) && !((int) $row['desbloqueos_count'] > 0),
            'estado_comercial' => $row['estado_comercial']
        ];

        $servicios[] = $servicio;
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

    // ✅ NUEVO: Determinar contexto de vista
    $vista_contexto = 'todos';
    if ($aplicar_filtro_responsable) {
        $vista_contexto = 'mis_servicios';
    }

    // RESPUESTA CON CONTEXTO DE USUARIO Y FILTRADO
    sendJsonResponse([
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
        'mensaje' => "Página $pagina de $totalPaginas ($totalRegistros servicios total)",
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol'],
        'vista_contexto' => $vista_contexto,
        'filtro_responsable_aplicado' => $aplicar_filtro_responsable,
        'usuario_id' => $usuario_id
    ]);
} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
