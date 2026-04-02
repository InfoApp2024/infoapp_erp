<?php
require_once '../login/auth_middleware.php';

try {
    // PASO 1: Requerir autenticación JWT
    $currentUser = requireAuth();

    // PASO 2: Log de acceso
    logAccess($currentUser, '/listar_equipos.php', 'view_equipments');

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
    $activo = isset($_GET['activo']) ? (int) $_GET['activo'] : null;
    $estado_id = isset($_GET['estado_id']) ? (int) $_GET['estado_id'] : null;

    // 🆕 NUEVO: Filtro por cliente
    $cliente_id = isset($_GET['cliente_id']) ? (int) $_GET['cliente_id'] : null;

    // 🆕 NUEVO: Parámetros de ordenamiento
    $sort_by = isset($_GET['sort_by']) ? trim($_GET['sort_by']) : 'id';
    $sort_order = isset($_GET['sort_order']) && strtoupper($_GET['sort_order']) === 'ASC' ? 'ASC' : 'DESC';

    // Campos válidos para evitar SQL Injection
    $validSortFields = [
        'id',
        'nombre',
        'modelo',
        'marca',
        'placa',
        'codigo',
        'nombre_empresa',
        'activo',
        'estado_id',
        'ciudad',
        'planta',
        'linea_prod'
    ];

    if (!in_array($sort_by, $validSortFields)) {
        $sort_by = 'id';
    }

    // Construir cláusulas SQL dinámicas
    $offset = ($pagina - 1) * $limite;
    $whereConditions = ["1=1"];
    $params = [];
    $types = "";

    // Filtro por búsqueda
    if (!empty($buscar)) {
        $whereConditions[] = "(
            e.nombre LIKE ? OR 
            e.modelo LIKE ? OR 
            e.marca LIKE ? OR 
            e.placa LIKE ? OR 
            e.codigo LIKE ? OR 
            e.nombre_empresa LIKE ?
        )";
        $searchTerm = "%$buscar%";
        $params = array_merge($params, [$searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm, $searchTerm]);
        $types .= "ssssss";
    }

    // Filtro por estado activo/inactivo (activo=1, inactivo=0)
    if ($activo !== null && in_array($activo, [0, 1])) {
        $whereConditions[] = "e.activo = ?";
        $params[] = $activo;
        $types .= "i";
    }

    // Filtro por estado_id (ID de la tabla estados)
    if ($estado_id !== null && $estado_id > 0) {
        $whereConditions[] = "e.estado_id = ?";
        $params[] = $estado_id;
        $types .= "i";
    }

    // 🆕 NUEVO: Filtro por cliente
    if ($cliente_id !== null && $cliente_id > 0) {
        $whereConditions[] = "e.cliente_id = ?";
        $params[] = $cliente_id;
        $types .= "i";
    }

    // 🔒 SEGURIDAD: Filtrado obligatorio para rol cliente
    if ($currentUser['rol'] === 'cliente') {
        if (!isset($currentUser['cliente_id']) || empty($currentUser['cliente_id'])) {
            throw new Exception("Error de seguridad: Usuario cliente sin cliente_id asignado.");
        }

        // Si ya había un filtro de cliente_id (por GET), lo buscamos para reemplazarlo
        // y evitar duplicidad o inconsistencia en $params/$types
        $clienteKey = array_search("e.cliente_id = ?", $whereConditions);

        if ($clienteKey !== false) {
            // Ya existía la condición, ubicamos su posición en los params
            $paramIndex = 0;
            for ($i = 0; $i < $clienteKey; $i++) {
                if (strpos($whereConditions[$i], "?") !== false) {
                    $paramIndex += substr_count($whereConditions[$i], "?");
                }
            }
            $params[$paramIndex] = $currentUser['cliente_id'];
        } else {
            $whereConditions[] = "e.cliente_id = ?";
            $params[] = $currentUser['cliente_id'];
            $types .= "i";
        }
    }


    $whereClause = "WHERE " . implode(" AND ", $whereConditions);
    $orderClause = "ORDER BY e.$sort_by $sort_order";

    // QUERY PRINCIPAL
    $sqlEquipos = "SELECT 
                e.id, 
                e.nombre, 
                e.modelo, 
                e.marca, 
                e.placa, 
                e.codigo,
                e.ciudad,
                e.planta,
                e.linea_prod,
                e.nombre_empresa,
                e.usuario_registro,
                e.cliente_id,
                e.activo,
                e.estado_id,
                ep.nombre_estado as estado_nombre,
                ep.color as estado_color
            FROM equipos e
            LEFT JOIN estados_proceso ep ON e.estado_id = ep.id
            $whereClause
            $orderClause
            LIMIT ? OFFSET ?";

    // QUERY PARA TOTAL
    $sqlTotal = "SELECT COUNT(*) as total FROM equipos e $whereClause";

    // Re-ejecutar con alias 'e'
    $stmt = $conn->prepare($sqlEquipos);
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
    $equipos = [];

    while ($row = $result->fetch_assoc()) {
        $equipos[] = [
            'id' => (int) $row['id'],
            'nombre' => $row['nombre'],
            'modelo' => $row['modelo'],
            'marca' => $row['marca'],
            'placa' => $row['placa'],
            'codigo' => $row['codigo'],
            'ciudad' => $row['ciudad'],
            'planta' => $row['planta'],
            'linea_prod' => $row['linea_prod'],
            'nombre_empresa' => $row['nombre_empresa'],
            'usuario_registro' => $row['usuario_registro'],
            'cliente_id' => $row['cliente_id'] !== null ? (int) $row['cliente_id'] : null,
            'activo' => (int) $row['activo'],
            'estado_id' => $row['estado_id'] !== null ? (int) $row['estado_id'] : null,
            'estado_nombre' => $row['estado_nombre'] ?? 'Sin estado',
            'estado_color' => $row['estado_color'] ?? '#808080',
            'descripcion' => trim(
                $row['nombre'] .
                (!empty($row['modelo']) ? " - {$row['modelo']}" : "") .
                (!empty($row['marca']) ? " ({$row['marca']})" : "")
            )
        ];
    }

    // --- OPTIMIZACIÓN V2: Carga de Campos Adicionales (Request Merging) ---
    $datosAdicionales = [];
    $idsEquipos = array_column($equipos, 'id');

    if (!empty($idsEquipos)) {
        // Crear placeholders (?,?,?)
        $placeholders = implode(',', array_fill(0, count($idsEquipos), '?'));
        // Module puede ser 'Equipos' o 'equipo' dependiendo de la configuración
        // Usamos IN para que traiga ambos si existen inconsistencias
        $sqlAdicionales = "
            SELECT 
                vca.id,
                vca.servicio_id,
                vca.campo_id,
                vca.valor_texto,
                vca.valor_numero,
                vca.valor_fecha,
                vca.valor_hora,
                vca.valor_datetime,
                vca.valor_archivo,
                vca.valor_booleano,
                vca.tipo_campo as valor_tipo_guardado,
                vca.fecha_creacion,
                vca.fecha_actualizacion,
                ca.nombre_campo,
                ca.tipo_campo as campo_tipo_configurado,
                ca.obligatorio,
                ca.modulo
            FROM valores_campos_adicionales vca
            INNER JOIN campos_adicionales ca ON vca.campo_id = ca.id
            WHERE vca.servicio_id IN ($placeholders)
            AND (ca.modulo = 'Equipos' OR ca.modulo = 'equipo')
            ORDER BY vca.servicio_id, ca.id ASC
        ";

        $stmtAd = $conn->prepare($sqlAdicionales);
        if ($stmtAd) {
            $typesAd = str_repeat('i', count($idsEquipos));
            $stmtAd->bind_param($typesAd, ...$idsEquipos);
            if ($stmtAd->execute()) {
                $resAd = $stmtAd->get_result();
                while ($row = $resAd->fetch_assoc()) {
                    $servicio_id = (int) $row['servicio_id'];
                    if (!isset($datosAdicionales[$servicio_id])) {
                        $datosAdicionales[$servicio_id] = [];
                    }

                    // Lógica simplificada de valor final
                    $valorFinal = null;
                    $tipoCampo = $row['campo_tipo_configurado'];

                    switch ($tipoCampo) {
                        case 'Texto':
                        case 'Párrafo':
                        case 'Link':
                            $valorFinal = $row['valor_texto'];
                            break;
                        case 'Entero':
                            $valorFinal = $row['valor_numero'] !== null ? (int) $row['valor_numero'] : null;
                            break;
                        case 'Decimal':
                        case 'Moneda':
                            $valorFinal = $row['valor_numero'] !== null ? (float) $row['valor_numero'] : null;
                            break;
                        case 'Fecha':
                            $valorFinal = $row['valor_fecha'];
                            break;
                        case 'Hora':
                            $valorFinal = $row['valor_hora'];
                            break;
                        case 'Datetime':
                        case 'Fecha y hora':
                            $valorFinal = $row['valor_datetime'];
                            break;
                        case 'Imagen':
                        case 'Archivo':
                            $valorFinal = $row['valor_archivo'];
                            break;
                        case 'Booleano':
                            $valorFinal = $row['valor_booleano'] == 1;
                            break;
                        default:
                            if ($row['valor_texto'] !== null && $row['valor_texto'] !== '')
                                $valorFinal = $row['valor_texto'];
                            elseif ($row['valor_numero'] !== null)
                                $valorFinal = $row['valor_numero'];
                    }

                    if ($valorFinal !== null && $valorFinal !== '') {
                        $datosAdicionales[$servicio_id][] = [
                            'id' => (int) $row['id'],
                            'campo_id' => (int) $row['campo_id'],
                            'nombre_campo' => $row['nombre_campo'],
                            'tipo_campo' => $tipoCampo,
                            'valor' => $valorFinal,
                            'obligatorio' => (int) $row['obligatorio'],
                            'modulo' => $row['modulo']
                        ];
                    }
                }
            }
            $stmtAd->close();
        }
    }
    // -------------------------------------------------------------

    // Ejecutar query total
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

    // RESPUESTA FINAL
    sendJsonResponse([
        'success' => true,
        'data' => [
            'equipos' => $equipos,
            'paginacion' => [
                'pagina_actual' => $pagina,
                'limite' => $limite,
                'total_registros' => (int) $totalRegistros,
                'total_paginas' => (int) $totalPaginas,
                'tiene_siguiente' => $pagina < $totalPaginas,
                'tiene_anterior' => $pagina > 1,
                'equipos_en_pagina' => count($equipos)
            ],
            'campos_adicionales' => $datosAdicionales // 🆕 Datos Merged
        ],
        'mensaje' => "Página $pagina de $totalPaginas ($totalRegistros equipos total)",
        'loaded_by' => $currentUser['usuario'],
        'user_role' => $currentUser['rol'],
        'orden' => [
            'campo' => $sort_by,
            'direccion' => $sort_order
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>