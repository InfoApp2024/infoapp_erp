<?php
// obtener_servicio.php - Obtener detalle completo de un servicio - Protegido con JWT

require_once '../login/auth_middleware.php';

try {
    // 1. Requerir autenticación JWT
    $currentUser = requireAuth();

    // 2. Log de acceso
    logAccess($currentUser, '/servicio/obtener_servicio.php', 'view_service_detail');

    // 3. Validar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    // 4. Conexión a BD
    require '../conexion.php';

    // 5. Obtener ID del servicio
    $servicio_id = isset($_GET['id']) ? (int) $_GET['id'] : null;

    if (!$servicio_id) {
        throw new Exception('ID de servicio requerido');
    }

    // 6. SQL Query (Similar a listar_servicios.php pero filtrado por ID)
    $sql = "SELECT 
                s.id,
                (SELECT COUNT(*) FROM notas n WHERE n.id_servicio = s.id) as cantidad_notas,
                (SELECT COUNT(*) FROM firmas fi WHERE fi.id_servicio = s.id) as tiene_firma_count,
                (SELECT COUNT(*) FROM servicios_desbloqueos_repuestos dr WHERE dr.servicio_id = s.id AND dr.usado = 0) as desbloqueos_count,
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
                s.estado as estado_id,
                s.suministraron_repuestos,
                s.fotos_confirmadas,
                s.firma_confirmada,
                s.personal_confirmado,
                s.fecha_finalizacion,
                s.anular_servicio,
                s.razon,
                s.actividad_id,
                s.responsable_id,
                s.usuario_creador,
                s.usuario_ultima_actualizacion,
                
                -- Agregar nombre de la actividad y métricas
                ae.actividad as actividad_nombre,
                ae.cant_hora,
                (SELECT COUNT(*) FROM servicio_staff ss WHERE ss.servicio_id = s.id) as num_tecnicos_real,
                ae.num_tecnicos as num_tecnicos_estandar,
                st.nombre as sistema_nombre,
                
                e.nombre_estado as estado_nombre,
                e.color as estado_color,
                
                f.nombre as autorizado_por_nombre,
                
                eq.nombre as equipo_nombre,
                eq.modelo as equipo_modelo,
                eq.marca as equipo_marca,
                eq.codigo as equipo_codigo,
                
                c.nombre_completo as cliente_nombre, -- ✅ Cliente (CORREGIDO)
                fr.nombre as funcionario_nombre, -- ✅ Responsable
                s.cliente_id,
                s.responsable_id as funcionario_id
                
            FROM servicios s
            LEFT JOIN estados_proceso e ON s.estado = e.id
            LEFT JOIN funcionario f ON s.autorizado_por = f.id
            LEFT JOIN equipos eq ON s.id_equipo = eq.id
            LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
            LEFT JOIN sistemas st ON ae.sistema_id = st.id -- ✅ JOIN Sistemas
            LEFT JOIN clientes c ON s.cliente_id = c.id  -- ✅ JOIN Clientes
            LEFT JOIN funcionario fr ON s.responsable_id = fr.id -- ✅ JOIN Responsable
            LEFT JOIN funcionario f_creador ON s.usuario_creador = f_creador.id -- ✅ JOIN Creador
            LEFT JOIN funcionario f_actualiza ON s.usuario_ultima_actualizacion = f_actualiza.id -- ✅ JOIN Actualizador
            
            WHERE s.id = ? LIMIT 1";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $servicio_id);

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    if (!$row) {
        throw new Exception("Servicio no encontrado con ID: $servicio_id");
    }

    // 7. Estructurar respuesta compatible con ServicioModel.fromJson
    $servicio = [
        'id' => (int) $row['id'],
        'o_servicio' => (int) $row['o_servicio'],
        'fecha_ingreso' => $row['fecha_ingreso'],
        'orden_cliente' => $row['orden_cliente'],
        'autorizado_por' => (int) $row['autorizado_por'],
        'tipo_mantenimiento' => $row['tipo_mantenimiento'],
        'centro_costo' => $row['centro_costo'],
        'id_equipo' => (int) $row['id_equipo'],
        'equipo_nombre' => $row['equipo_nombre'],
        'nombre_emp' => $row['nombre_emp'],
        'placa' => $row['placa'],
        'estado_id' => (int) $row['estado_id'],
        'estado_nombre' => $row['estado_nombre'] ?? 'Sin estado',
        'estado_color' => $row['estado_color'] ?? '#808080',
        'suministraron_repuestos' => (int) $row['suministraron_repuestos'] === 1,
        'fotos_confirmadas' => (int) $row['fotos_confirmadas'] === 1,
        'firma_confirmada' => (int) $row['firma_confirmada'] === 1,
        'personal_confirmado' => (int) $row['personal_confirmado'] === 1,
        'fecha_finalizacion' => $row['fecha_finalizacion'],
        'anular_servicio' => (int) $row['anular_servicio'] === 1,
        'razon' => $row['razon'],
        'actividad_id' => $row['actividad_id'] !== null ? (int) $row['actividad_id'] : null,
        'actividad_nombre' => $row['actividad_nombre'],
        'cant_hora' => $row['cant_hora'] !== null ? (float) $row['cant_hora'] : 0.0,
        'num_tecnicos' => $row['num_tecnicos_real'] !== null ? (int) $row['num_tecnicos_real'] : 0,
        'num_tecnicos_estandar' => $row['num_tecnicos_estandar'] !== null ? (int) $row['num_tecnicos_estandar'] : 1,
        'sistema_nombre' => $row['sistema_nombre'] ?? '',
        'usuario_creador' => $row['usuario_creador'] !== null ? (int) $row['usuario_creador'] : null,
        'usuario_ultima_actualizacion' => $row['usuario_ultima_actualizacion'] !== null ? (int) $row['usuario_ultima_actualizacion'] : null,
        'cantidad_notas' => (int) $row['cantidad_notas'],
        'tiene_firma' => (int) $row['tiene_firma_count'] > 0,
        'bloqueo_repuestos' => ((int) $row['tiene_firma_count'] > 0) && !((int) $row['desbloqueos_count'] > 0),
        'cliente_id' => $row['cliente_id'] !== null ? (int) $row['cliente_id'] : null, // ✅ NUEVO
        'cliente_nombre' => $row['cliente_nombre'], // ✅ NUEVO
        'funcionario_id' => $row['funcionario_id'] !== null ? (int) $row['funcionario_id'] : null, // ✅ NUEVO
        'funcionario_nombre' => $row['funcionario_nombre'] // ✅ NUEVO
    ];

    sendJsonResponse([
        'success' => true,
        'data' => $servicio,
        'message' => 'Servicio obtenido exitosamente'
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>