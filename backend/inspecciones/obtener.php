<?php
// obtener.php - Obtener detalle completo de una inspección - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/obtener.php', 'view_inspection_detail');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    $inspeccion_id = isset($_GET['id']) ? (int) $_GET['id'] : null;

    if (!$inspeccion_id) {
        throw new Exception('ID de inspección requerido');
    }

    // 1. Obtener datos principales de la inspección
    $sql = "SELECT 
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
                eq.codigo as equipo_codigo,
                eq.ciudad as equipo_ciudad,
                eq.planta as equipo_planta,
                eq.nombre_empresa as equipo_empresa,
                eq.cliente_id,
                
                u_creador.NOMBRE_USER as creado_por_nombre,
                u_actualizo.NOMBRE_USER as actualizado_por_nombre
                
            FROM inspecciones i
            LEFT JOIN estados_proceso e ON i.estado_id = e.id
            LEFT JOIN equipos eq ON i.equipo_id = eq.id
            LEFT JOIN usuarios u_creador ON i.created_by = u_creador.id
            LEFT JOIN usuarios u_actualizo ON i.updated_by = u_actualizo.id
            WHERE i.id = ? AND i.deleted_at IS NULL";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $inspeccion_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $inspeccion = $result->fetch_assoc();

    if (!$inspeccion) {
        throw new Exception('Inspección no encontrada');
    }

    // 2. Obtener inspectores
    $sql_inspectores = "SELECT 
                            ii.id,
                            ii.usuario_id,
                            ii.rol_inspector,
                            u.NOMBRE_USER as nombre,
                            u.NOMBRE_CLIENTE as username,
                            u.CORREO as email
                        FROM inspecciones_inspectores ii
                        LEFT JOIN usuarios u ON ii.usuario_id = u.id
                        WHERE ii.inspeccion_id = ?
                        ORDER BY ii.id ASC";

    $stmt_inspectores = $conn->prepare($sql_inspectores);
    $stmt_inspectores->bind_param("i", $inspeccion_id);
    $stmt_inspectores->execute();
    $result_inspectores = $stmt_inspectores->get_result();
    $inspectores = [];

    while ($row = $result_inspectores->fetch_assoc()) {
        $inspectores[] = [
            'id' => (int) $row['id'],
            'usuario_id' => (int) $row['usuario_id'],
            'rol_inspector' => $row['rol_inspector'],
            'nombre' => $row['nombre'] ?? 'Desconocido',
            'username' => $row['username'] ?? '',
            'email' => $row['email'] ?? ''
        ];
    }

    // 3. Obtener sistemas
    $sql_sistemas = "SELECT 
                        is_rel.id,
                        is_rel.sistema_id,
                        s.nombre,
                        s.descripcion
                    FROM inspecciones_sistemas is_rel
                    LEFT JOIN sistemas s ON is_rel.sistema_id = s.id
                    WHERE is_rel.inspeccion_id = ?
                    ORDER BY s.nombre ASC";

    $stmt_sistemas = $conn->prepare($sql_sistemas);
    $stmt_sistemas->bind_param("i", $inspeccion_id);
    $stmt_sistemas->execute();
    $result_sistemas = $stmt_sistemas->get_result();
    $sistemas = [];

    while ($row = $result_sistemas->fetch_assoc()) {
        $sistemas[] = [
            'id' => (int) $row['id'],
            'sistema_id' => (int) $row['sistema_id'],
            'nombre' => $row['nombre'] ?? 'Desconocido',
            'descripcion' => $row['descripcion'] ?? ''
        ];
    }

    // 4. Obtener actividades
    $sql_actividades = "SELECT 
                            ia.id,
                            ia.actividad_id,
                            ia.autorizada,
                            ia.autorizado_por_id,
                            ia.orden_cliente,
                            ia.servicio_id,
                            ia.notas,
                            ia.fecha_autorizacion,
                            ia.created_at,
                            ia.updated_at,
                            ia.deleted_at,
                            
                            ae.actividad as actividad_nombre,
                            '' as actividad_descripcion,
                            
                            u_autorizo.NOMBRE_USER as autorizado_por_nombre,
                            
                            s.o_servicio as servicio_numero,
                            s.fecha_registro as servicio_fecha,
                            u_serv.NOMBRE_USER as aprobado_por_nombre,
                            u_reg.NOMBRE_USER as registrado_por_nombre,
                            u_del.NOMBRE_USER as eliminado_por_nombre,
                            f_aval.nombre as avalador_nombre
                        FROM inspecciones_actividades ia
                        LEFT JOIN actividades_estandar ae ON ia.actividad_id = ae.id
                        LEFT JOIN usuarios u_autorizo ON ia.autorizado_por_id = u_autorizo.id
                        LEFT JOIN usuarios u_reg ON ia.created_by = u_reg.id
                        LEFT JOIN usuarios u_del ON ia.deleted_by = u_del.id
                        LEFT JOIN servicios s ON ia.servicio_id = s.id
                        LEFT JOIN usuarios u_serv ON s.usuario_creador = u_serv.id
                        LEFT JOIN funcionario f_aval ON s.autorizado_por = f_aval.id
                        WHERE ia.inspeccion_id = ?
                        ORDER BY ia.id ASC";

    $stmt_actividades = $conn->prepare($sql_actividades);
    $stmt_actividades->bind_param("i", $inspeccion_id);
    $stmt_actividades->execute();
    $result_actividades = $stmt_actividades->get_result();
    $actividades = [];

    while ($row = $result_actividades->fetch_assoc()) {
        $actividades[] = [
            'id' => (int) $row['id'],
            'actividad_id' => (int) $row['actividad_id'],
            'actividad_nombre' => $row['actividad_nombre'] ?? 'Desconocida',
            'actividad_descripcion' => $row['actividad_descripcion'] ?? '',
            'autorizada' => (bool) $row['autorizada'],
            'autorizado_por_id' => $row['autorizado_por_id'] ? (int) $row['autorizado_por_id'] : null,
            'autorizado_por_nombre' => $row['autorizado_por_nombre'] ?? null,
            'orden_cliente' => $row['orden_cliente'] ?? null,
            'servicio_id' => $row['servicio_id'] ? (int) $row['servicio_id'] : null,
            'servicio_numero' => $row['servicio_numero'] ? (int) $row['servicio_numero'] : null,
            'servicio_fecha' => $row['servicio_fecha'],
            'avalador_nombre' => $row['avalador_nombre'] ?? null,
            'aprobado_por_nombre' => $row['aprobado_por_nombre'] ?? null,
            'registrado_por_nombre' => $row['registrado_por_nombre'] ?? 'N/A',
            'eliminado_por_nombre' => $row['eliminado_por_nombre'],
            'notas' => $row['notas'] ?? '',
            'fecha_autorizacion' => $row['fecha_autorizacion'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
            'deleted_at' => $row['deleted_at']
        ];
    }

    // 5. Obtener evidencias
    $sql_evidencias = "SELECT 
                            ie.id,
                            ie.actividad_id,
                            ie.ruta_imagen,
                            ie.comentario,
                            ie.orden,
                            ie.created_at,
                            ie.created_by,
                            
                            u_creo.NOMBRE_USER as creado_por_nombre
                        FROM inspecciones_evidencias ie
                        LEFT JOIN usuarios u_creo ON ie.created_by = u_creo.id
                        WHERE ie.inspeccion_id = ?
                        ORDER BY ie.orden ASC, ie.id ASC";

    $stmt_evidencias = $conn->prepare($sql_evidencias);
    $stmt_evidencias->bind_param("i", $inspeccion_id);
    $stmt_evidencias->execute();
    $result_evidencias = $stmt_evidencias->get_result();
    $evidencias = [];

    while ($row = $result_evidencias->fetch_assoc()) {
        $evidencias[] = [
            'id' => (int) $row['id'],
            'actividad_id' => $row['actividad_id'] ? (int) $row['actividad_id'] : null,
            'ruta_imagen' => $row['ruta_imagen'],
            'comentario' => $row['comentario'] ?? '',
            'orden' => (int) $row['orden'],
            'created_at' => $row['created_at'],
            'creado_por_nombre' => $row['creado_por_nombre'] ?? 'Desconocido'
        ];
    }

    // Construir respuesta completa
    $response = [
        'id' => (int) $inspeccion['id'],
        'o_inspe' => $inspeccion['o_inspe'],
        'estado_id' => (int) $inspeccion['estado_id'],
        'estado_nombre' => $inspeccion['estado_nombre'] ?? 'Sin estado',
        'estado_color' => $inspeccion['estado_color'] ?? '#808080',
        'es_final' => (bool) $inspeccion['es_final'],
        'sitio' => $inspeccion['sitio'],
        'fecha_inspe' => $inspeccion['fecha_inspe'],
        'equipo_id' => (int) $inspeccion['equipo_id'],
        'cliente_id' => $inspeccion['cliente_id'] ? (int) $inspeccion['cliente_id'] : null,
        'equipo' => [
            'id' => (int) $inspeccion['equipo_id'],
            'nombre' => $inspeccion['equipo_nombre'] ?? 'Desconocido',
            'placa' => $inspeccion['equipo_placa'] ?? '',
            'modelo' => $inspeccion['equipo_modelo'] ?? '',
            'marca' => $inspeccion['equipo_marca'] ?? '',
            'codigo' => $inspeccion['equipo_codigo'] ?? '',
            'ciudad' => $inspeccion['equipo_ciudad'] ?? '',
            'planta' => $inspeccion['equipo_planta'] ?? '',
            'nombre_empresa' => $inspeccion['equipo_empresa'] ?? ''
        ],
        'created_at' => $inspeccion['created_at'],
        'updated_at' => $inspeccion['updated_at'],
        'creado_por_nombre' => $inspeccion['creado_por_nombre'] ?? 'Desconocido',
        'actualizado_por_nombre' => $inspeccion['actualizado_por_nombre'] ?? 'Desconocido',
        'inspectores' => $inspectores,
        'sistemas' => $sistemas,
        'actividades' => $actividades,
        'evidencias' => $evidencias,
        'totales' => [
            'inspectores' => count($inspectores),
            'sistemas' => count($sistemas),
            'actividades' => count(array_filter($actividades, fn($a) => is_null($a['deleted_at']))),
            'actividades_autorizadas' => count(array_filter($actividades, fn($a) => $a['autorizada'] && is_null($a['servicio_id']) && is_null($a['deleted_at']))),
            'actividades_eliminadas' => count(array_filter($actividades, fn($a) => !is_null($a['deleted_at']))),
            'actividades_vinculadas' => count(array_filter($actividades, fn($a) => !is_null($a['servicio_id']) && is_null($a['deleted_at']))),
            'evidencias' => count($evidencias)
        ]
    ];

    sendJsonResponse([
        'success' => true,
        'data' => $response
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>