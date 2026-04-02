<?php
// crear_servicio_desde_actividad.php - Crear servicio desde actividad autorizada - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/crear_servicio_desde_actividad.php', 'create_service_from_inspection');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';
    require '../servicio/WebSocketNotifier.php';
    require 'helpers/inspeccion_helper.php';

    $raw_input = file_get_contents('php://input');
    $input = json_decode($raw_input, true);

    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    $inspeccion_actividad_id = $input['inspeccion_actividad_id'] ?? null;
    $autorizado_por = $input['autorizado_por'] ?? null;
    $orden_cliente = $input['orden_cliente'] ?? '';
    $tipo_mantenimiento = $input['tipo_mantenimiento'] ?? 'correctivo';
    $centro_costo = $input['centro_costo'] ?? '';
    $estado_id = $input['estado_id'] ?? null;
    $nota_input = $input['nota'] ?? '';
    $cliente_id = $input['cliente_id'] ?? null;
    $usuario_id = $currentUser['id'];

    // Validaciones
    if (!$inspeccion_actividad_id) {
        throw new Exception('ID de actividad de inspección requerido');
    }

    if (!$autorizado_por) {
        throw new Exception('Autorizado por requerido');
    }

    if (!$estado_id) {
        throw new Exception('Estado requerido');
    }

    if (!$cliente_id) {
        throw new Exception('Cliente requerido');
    }

    // Obtener datos de la inspección y actividad
    $sql = "SELECT 
                ia.id,
                ia.inspeccion_id,
                ia.actividad_id,
                ia.autorizada,
                ia.servicio_id,
                ia.autorizado_por_id,
                i.equipo_id,
                i.fecha_inspe,
                eq.nombre_empresa,
                eq.placa
            FROM inspecciones_actividades ia
            INNER JOIN inspecciones i ON ia.inspeccion_id = i.id
            INNER JOIN equipos eq ON i.equipo_id = eq.id
            WHERE ia.id = ?";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $inspeccion_actividad_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $actividad_inspeccion = $result->fetch_assoc();

    if (!$actividad_inspeccion) {
        throw new Exception('Actividad de inspección no encontrada');
    }

    // Verificar que la actividad esté autorizada
    if (!$actividad_inspeccion['autorizada']) {
        throw new Exception('La actividad no está autorizada');
    }

    // 🔒 SEGURIDAD: Si el usuario es cliente, forzamos su cliente_id y validamos el autorizador
    if ($currentUser['rol'] === 'cliente') {
        if (!isset($currentUser['cliente_id']) || empty($currentUser['cliente_id'])) {
            throw new Exception("Error de seguridad: Usuario cliente sin cliente_id.");
        }

        $cliente_id = $currentUser['cliente_id']; // Asegurar el cliente del token

        // El cliente solo puede autorizar él mismo (su funcionario_id)
        // O usar el autorizador que ya tiene la actividad grabada (herencia/delegación)
        $autorizador_original = isset($actividad_inspeccion['autorizado_por_id']) ? $actividad_inspeccion['autorizado_por_id'] : null;

        if ($autorizado_por != $currentUser['funcionario_id'] && $autorizado_por != $autorizador_original) {
            throw new Exception("Error de seguridad: Un cliente solo puede autorizar usando su propio registro de funcionario o manteniendo el oficial que autorizó la actividad original.");
        }

        // Nota obligatoria para clientes
        if (empty(trim($nota_input))) {
            throw new Exception("La nota es obligatoria cuando un cliente autoriza el servicio.");
        }
    }

    // Verificar que no se haya creado ya un servicio
    if ($actividad_inspeccion['servicio_id']) {
        throw new Exception('Ya existe un servicio creado para esta actividad');
    }

    // Iniciar transacción
    $conn->begin_transaction();

    try {
        // 1. Obtener el siguiente número de servicio
        $stmt_num = $conn->prepare("SELECT MAX(o_servicio) as ultimo_numero FROM servicios");
        $stmt_num->execute();
        $result_num = $stmt_num->get_result();
        $row_num = $result_num->fetch_assoc();
        $ultimo_numero = intval($row_num['ultimo_numero'] ?? 0);
        $o_servicio = $ultimo_numero + 1;
        $stmt_num->close();

        // 2. Crear el servicio
        $fecha_ingreso = $actividad_inspeccion['fecha_inspe'];
        $fecha_ingreso_formatted = date('Y-m-d H:i:s', strtotime($fecha_ingreso));

        $sql_servicio = "INSERT INTO servicios (
                    o_servicio, fecha_registro, fecha_ingreso, orden_cliente, 
                    autorizado_por, tipo_mantenimiento, centro_costo, id_equipo, 
                    nombre_emp, placa, estado, actividad_id, 
                    suministraron_repuestos, anular_servicio, es_finalizado,
                    usuario_creador, usuario_ultima_actualizacion, cliente_id, responsable_id
                ) VALUES (
                    ?, NOW(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, 0, ?, ?, ?, ?
                )";

        $stmt_servicio = $conn->prepare($sql_servicio);
        $stmt_servicio->bind_param(
            "issississiiiiii",
            $o_servicio,
            $fecha_ingreso_formatted,
            $orden_cliente,
            $autorizado_por,
            $tipo_mantenimiento,
            $centro_costo,
            $actividad_inspeccion['equipo_id'],
            $actividad_inspeccion['nombre_empresa'],
            $actividad_inspeccion['placa'],
            $estado_id,
            $actividad_inspeccion['actividad_id'],
            $usuario_id,
            $usuario_id,
            $cliente_id,
            $usuario_id
        );

        if (!$stmt_servicio->execute()) {
            throw new Exception('Error creando servicio: ' . $stmt_servicio->error);
        }

        $servicio_id = $conn->insert_id;
        $stmt_servicio->close();

        // 3. Actualizar la actividad de inspección con el servicio creado y asegurar autorización/fecha
        $sql_update = "UPDATE inspecciones_actividades 
                       SET servicio_id = ?, 
                           autorizado_por_id = ?, 
                           orden_cliente = ?,
                           autorizada = 1,
                           fecha_autorizacion = NOW()
                       WHERE id = ?";

        $stmt_update = $conn->prepare($sql_update);
        $stmt_update->bind_param("iisi", $servicio_id, $autorizado_por, $orden_cliente, $inspeccion_actividad_id);

        if (!$stmt_update->execute()) {
            throw new Exception('Error actualizando actividad de inspección: ' . $stmt_update->error);
        }
        $stmt_update->close();

        // 4. Crear nota automática de trazabilidad
        date_default_timezone_set('America/Bogota');
        $system_note = "Servicio creado desde una inspección.";
        $fecha_nota = date('Y-m-d');
        $hora_nota = date('H:i:s');
        $usuario_nota = $currentUser['usuario'];

        // Nota del sistema (automática)
        $stmt_nota_auto = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id, es_automatica) VALUES (?, ?, ?, ?, ?, ?, 1)");
        $stmt_nota_auto->bind_param("issssi", $servicio_id, $system_note, $fecha_nota, $hora_nota, $usuario_nota, $usuario_id);

        if (!$stmt_nota_auto->execute()) {
            error_log("Error creando nota de trazabilidad automática: " . $stmt_nota_auto->error);
        }
        $stmt_nota_auto->close();

        // Nota opcional del usuario (manual)
        if (!empty($nota_input)) {
            $stmt_nota_manual = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id, es_automatica) VALUES (?, ?, ?, ?, ?, ?, 0)");
            $stmt_nota_manual->bind_param("issssi", $servicio_id, $nota_input, $fecha_nota, $hora_nota, $usuario_nota, $usuario_id);

            if (!$stmt_nota_manual->execute()) {
                error_log("Error creando nota manual del usuario: " . $stmt_nota_manual->error);
            }
            $stmt_nota_manual->close();
        }

        // Commit de la transacción
        $conn->commit();

        // 5. Verificar si la inspección debe finalizarse (ahora que esta actividad tiene servicio)
        $resultado_finalizacion = verificarYFinalizarInspeccion($conn, $actividad_inspeccion['inspeccion_id'], $usuario_id);

        // Notificar vía WebSocket
        try {
            $notifier = new WebSocketNotifier();

            // Notificar servicio creado
            $servicio_completo = $notifier->obtenerServicioCompleto($servicio_id, $conn);
            if ($servicio_completo) {
                $notifier->notificarServicioCreado($servicio_completo, $usuario_id);
            }

            // Notificar inspección actualizada
            $notifier->notificar([
                'tipo' => 'inspeccion_actividad_servicio_creado',
                'inspeccion_id' => $actividad_inspeccion['inspeccion_id'],
                'inspeccion_actividad_id' => $inspeccion_actividad_id,
                'servicio_id' => $servicio_id,
                'usuario_id' => $usuario_id
            ]);
        } catch (Exception $ws_error) {
            error_log("WebSocket error: " . $ws_error->getMessage());
        }

        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => 'Servicio creado exitosamente desde inspección',
            'data' => [
                'servicio_id' => (int) $servicio_id,
                'o_servicio' => (int) $o_servicio,
                'inspeccion_id' => (int) $actividad_inspeccion['inspeccion_id'],
                'inspeccion_actividad_id' => (int) $inspeccion_actividad_id,
                'numero_servicio_formateado' => sprintf('#%04d', $o_servicio),
                'inspeccion_finalizada' => $resultado_finalizacion['finalizada'],
                'nuevo_estado_inspeccion_id' => $resultado_finalizacion['nuevo_estado_id'] ?? null
            ]
        ], 201);

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($conn))
        $conn->close();
}
?>