<?php
// obtener_datos_servicio.php
// Función para obtener todos los datos de un servicio

function obtenerDatosServicio($servicio_id, $conn)
{
    log_debug("🔍 Obteniendo datos del servicio ID: $servicio_id");

    $datos = [
        'servicio' => null,
        'equipo' => null,
        'cliente' => null,
        'campos_adicionales' => [],
        'fotos' => [],
        'personal' => [],
        'repuestos' => [],
        'firmas' => [],
        'usuario' => null  // ← AGREGADO
    ];

    // ==================================================
    // 1. DATOS DEL SERVICIO
    // ==================================================
    log_debug("📋 Obteniendo datos básicos del servicio...");

    $sql_servicio = "
        SELECT 
            s.*,
            e.nombre_estado as estado_nombre,
            a.actividad as actividad_nombre,
            a.cant_hora as actividad_horas,
            a.num_tecnicos as actividad_tecnicos,
            st.nombre as sistema_nombre,
            f.nombre as autorizado_por_nombre,
            ur.NOMBRE_USER as responsable_nombre
        FROM servicios s
        LEFT JOIN estados_proceso e ON s.estado = e.id
        LEFT JOIN actividades_estandar a ON s.actividad_id = a.id
        LEFT JOIN sistemas st ON a.sistema_id = st.id
        LEFT JOIN funcionario f ON s.autorizado_por = f.id
        LEFT JOIN usuarios ur ON s.responsable_id = ur.id
        WHERE s.id = ?
    ";

    $stmt = $conn->prepare($sql_servicio);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        log_debug("❌ Servicio no encontrado");
        return null;
    }

    $datos['servicio'] = $result->fetch_assoc();
    log_debug("✅ Servicio obtenido: #" . $datos['servicio']['o_servicio']);
    $stmt->close();

    // Fallback robusto: asegurar actividad_nombre cuando exista actividad_id
    // Aunque la consulta principal ya intenta LEFT JOIN con actividades_estandar,
    // casos de datos incompletos podrían dejar 'actividad_nombre' vacío.
    if (
        isset($datos['servicio']) &&
        !empty($datos['servicio']['actividad_id']) &&
        empty($datos['servicio']['actividad_nombre'])
    ) {
        log_debug("🔍 Resolviendo actividad_nombre por fallback. actividad_id=" . $datos['servicio']['actividad_id']);
        $stmt_act = $conn->prepare("SELECT actividad FROM actividades_estandar WHERE id = ? LIMIT 1");
        if ($stmt_act) {
            $stmt_act->bind_param("i", $datos['servicio']['actividad_id']);
            $stmt_act->execute();
            $res_act = $stmt_act->get_result();
            if ($res_act && $res_act->num_rows > 0) {
                $row_act = $res_act->fetch_assoc();
                $datos['servicio']['actividad_nombre'] = $row_act['actividad'] ?? '';
                log_debug("✅ actividad_nombre resuelto por fallback: " . ($datos['servicio']['actividad_nombre'] ?? ''));
            } else {
                log_debug("⚠️ No se encontró actividad estándar para id=" . $datos['servicio']['actividad_id']);
            }
            $stmt_act->close();
        } else {
            log_debug("❌ Error preparando fallback de actividades_estandar: " . $conn->error);
        }
    }

    // ==================================================
    // 2. DATOS DEL EQUIPO
    // ==================================================
    $id_equipo = $datos['servicio']['id_equipo'];

    if ($id_equipo) {
        log_debug("📋 Obteniendo datos del equipo ID: $id_equipo");

        $stmt_equipo = $conn->prepare("SELECT * FROM equipos WHERE id = ?");
        $stmt_equipo->bind_param("i", $id_equipo);
        $stmt_equipo->execute();
        $result_equipo = $stmt_equipo->get_result();

        if ($result_equipo->num_rows > 0) {
            $datos['equipo'] = $result_equipo->fetch_assoc();
            log_debug("✅ Equipo obtenido: " . $datos['equipo']['nombre']);
        }

        $stmt_equipo->close();
    }

    // ==================================================
    // 3. DATOS DEL CLIENTE (desde equipo y tabla clientes)
    // ==================================================
    if ($datos['equipo']) {
        // Intentar buscar el ID real del cliente en la tabla `clientes` usando el nombre de la empresa
        $nombre_empresa = $datos['equipo']['nombre_empresa'];
        $cliente_real_id = null;

        // Normalizar nombre para búsqueda (opcional, pero recomendado si hay inconsistencias)
        // Por ahora búsqueda exacta
        $stmt_c = $conn->prepare("SELECT id FROM clientes WHERE nombre_completo = ? LIMIT 1");
        if ($stmt_c) {
            $stmt_c->bind_param("s", $nombre_empresa);
            $stmt_c->execute();
            $res_c = $stmt_c->get_result();
            if ($row_c = $res_c->fetch_assoc()) {
                $cliente_real_id = (int) $row_c['id'];
                log_debug("✅ Cliente real encontrado en tabla clientes: ID $cliente_real_id");
            } else {
                log_debug("⚠️ Cliente '$nombre_empresa' no encontrado en tabla clientes. Se usará NULL como ID.");
            }
            $stmt_c->close();
        }

        $datos['cliente'] = [
            'id' => $cliente_real_id, // ID real de la tabla clientes (puede ser null)
            'equipo_id' => $datos['equipo']['id'], // Guardamos ID de equipo por si acaso
            'nombre' => $datos['equipo']['nombre_empresa'],
            'ciudad' => $datos['equipo']['ciudad'],
            'planta' => $datos['equipo']['planta'],
            'codigo' => $datos['equipo']['codigo']
        ];
        log_debug("✅ Datos de cliente estructurados. ID Cliente: " . ($cliente_real_id ?? 'NULL'));
    }

    // ==================================================
    // 4. CAMPOS ADICIONALES
    // ==================================================
    log_debug("📋 Obteniendo campos adicionales...");

    $sql_campos = "
        SELECT 
            v.*,
            c.nombre_campo,
            c.tipo_campo
        FROM valores_campos_adicionales v
        INNER JOIN campos_adicionales c ON v.campo_id = c.id
        WHERE v.servicio_id = ?
    ";

    $stmt_campos = $conn->prepare($sql_campos);
    $stmt_campos->bind_param("i", $servicio_id);
    $stmt_campos->execute();
    $result_campos = $stmt_campos->get_result();

    while ($campo = $result_campos->fetch_assoc()) {
        // Determinar el valor según el tipo
        $valor = null;
        switch ($campo['tipo_campo']) {
            case 'Texto':
            case 'Párrafo':
                $valor = $campo['valor_texto'];
                break;
            case 'Decimal':
            case 'Moneda':
                $valor = $campo['valor_numero'];
                break;
            case 'Entero':
                $valor = $campo['valor_numero'];
                break;
            case 'Fecha':
                $valor = $campo['valor_fecha'];
                break;
            case 'Hora':
                $valor = $campo['valor_hora'];
                break;
            case 'Fecha y hora':
                $valor = $campo['valor_datetime'];
                break;
            case 'Link':
                $valor = $campo['valor_archivo'];
                break;
            case 'Archivo':
            case 'Imagen':
                $valor = $campo['valor_archivo'];
                break;
        }

        $datos['campos_adicionales'][] = [
            'campo_id' => $campo['campo_id'],
            'nombre_campo' => $campo['nombre_campo'],
            'tipo_campo' => $campo['tipo_campo'],
            'valor' => $valor
        ];
    }

    log_debug("✅ Campos adicionales obtenidos: " . count($datos['campos_adicionales']));
    $stmt_campos->close();

    // ==================================================
    // 5. FOTOS
    // ==================================================
    log_debug("📋 Obteniendo fotos...");

    $stmt_fotos = $conn->prepare("
        SELECT * FROM fotos_servicio 
        WHERE servicio_id = ? 
        ORDER BY tipo_foto, orden_visualizacion ASC, id ASC
    ");
    $stmt_fotos->bind_param("i", $servicio_id);
    $stmt_fotos->execute();
    $result_fotos = $stmt_fotos->get_result();

    while ($foto = $result_fotos->fetch_assoc()) {
        $datos['fotos'][] = $foto;
    }

    log_debug("✅ Fotos obtenidas: " . count($datos['fotos']));
    $stmt_fotos->close();

    // ==================================================
    // 6. PERSONAL ASIGNADO
    // ==================================================
    log_debug("📋 Obteniendo personal asignado...");

    $stmt_personal = $conn->prepare("
        SELECT 
            ss.*,
            u.NOMBRE_USER as nombre_usuario,
            u.NOMBRE_CLIENTE as apellido_usuario
        FROM servicio_staff ss
        LEFT JOIN usuarios u ON ss.staff_id = u.id
        WHERE ss.servicio_id = ?
    ");
    $stmt_personal->bind_param("i", $servicio_id);
    $stmt_personal->execute();
    $result_personal = $stmt_personal->get_result();

    while ($personal = $result_personal->fetch_assoc()) {
        // nombre_staff = NOMBRE_USER (nombre completo del usuario)
        $nombre = trim($personal['nombre_usuario'] ?? '');
        $apellido = trim($personal['apellido_usuario'] ?? '');
        $personal['nombre_staff'] = $nombre ?: $apellido ?: 'Sin nombre';
        $datos['personal'][] = $personal;
    }

    log_debug("✅ Personal obtenido: " . count($datos['personal']));
    $stmt_personal->close();

    // ==================================================
    // 6.1 OPERACIONES DEL SERVICIO
    // ==================================================
    log_debug("📋 Obteniendo operaciones del servicio...");

    $stmt_ops = $conn->prepare("
        SELECT 
            o.id,
            o.descripcion,
            o.observaciones,
            o.is_master,
            o.fecha_inicio,
            o.fecha_fin,
            ae.actividad as actividad_nombre
        FROM operaciones o
        LEFT JOIN actividades_estandar ae ON o.actividad_estandar_id = ae.id
        WHERE o.servicio_id = ?
        ORDER BY o.is_master DESC, o.created_at ASC
    ");
    $stmt_ops->bind_param("i", $servicio_id);
    $stmt_ops->execute();
    $result_ops = $stmt_ops->get_result();

    $datos['operaciones'] = [];
    while ($op = $result_ops->fetch_assoc()) {
        $datos['operaciones'][] = $op;
    }

    log_debug("✅ Operaciones obtenidas: " . count($datos['operaciones']));
    $stmt_ops->close();

    // ==================================================
    // 7. REPUESTOS
    // ==================================================
    log_debug("📋 Obteniendo repuestos...");

    $stmt_repuestos = $conn->prepare("
        SELECT 
            sr.*,
            i.name as item_nombre,
            i.sku as codigo,
            i.item_type as tipo
        FROM servicio_repuestos sr
        LEFT JOIN inventory_items i ON sr.inventory_item_id = i.id
        WHERE sr.servicio_id = ?
    ");
    $stmt_repuestos->bind_param("i", $servicio_id);
    $stmt_repuestos->execute();
    $result_repuestos = $stmt_repuestos->get_result();

    while ($repuesto = $result_repuestos->fetch_assoc()) {
        $datos['repuestos'][] = $repuesto;
    }

    log_debug("✅ Repuestos obtenidos: " . count($datos['repuestos']));
    $stmt_repuestos->close();

    // ==================================================
    // 8. FIRMAS
    // ==================================================
    log_debug("📋 Obteniendo firmas...");

    $stmt_firmas = $conn->prepare("
        SELECT 
            f.*,
            COALESCE(u.NOMBRE_USER, CONCAT(s.first_name, ' ', s.last_name)) as staff_nombre_real,
            COALESCE(u.CORREO, s.email) as staff_correo_real,
            func.nombre as func_nombre_real
        FROM firmas f
        LEFT JOIN usuarios u ON f.id_staff_entrega = u.id AND f.id_staff_entrega <= 1000000
        LEFT JOIN staff s ON (f.id_staff_entrega - 1000000) = s.id AND f.id_staff_entrega > 1000000
        LEFT JOIN funcionario func ON f.id_funcionario_recibe = func.id
        WHERE f.id_servicio = ?
    ");
    $stmt_firmas->bind_param("i", $servicio_id);
    $stmt_firmas->execute();
    $result_firmas = $stmt_firmas->get_result();

    if ($result_firmas->num_rows > 0) {
        $firmas_row = $result_firmas->fetch_assoc();
        $firmas_row['nombre_staff'] = $firmas_row['staff_nombre_real'] ?? 'N/A';
        $firmas_row['correo_staff'] = $firmas_row['staff_correo_real'] ?? '';
        $firmas_row['nombre_funcionario'] = $firmas_row['func_nombre_real'] ?? 'N/A';
        $datos['firmas'] = $firmas_row;
        log_debug("✅ Firmas obtenidas");
    }

    $stmt_firmas->close();

    // ==================================================
    // 9. OBTENER DATOS DEL USUARIO CREADOR
    // ==================================================
    $usuario_creador_id = $datos['servicio']['usuario_creador'] ?? null;

    if ($usuario_creador_id) {
        log_debug("📋 Obteniendo datos del usuario creador ID: $usuario_creador_id");
        $datos['usuario'] = obtenerDatosUsuario($usuario_creador_id, $conn);
    } else {
        log_debug("⚠️ No hay usuario_creador en el servicio");
    }

    log_debug("✅ Todos los datos del servicio obtenidos correctamente");

    return $datos;
}

// ==================================================
// FUNCIÓN: OBTENER DATOS DEL USUARIO CREADOR
// ==================================================
function obtenerDatosUsuario($usuario_id, $conn)
{
    log_debug("   🔍 Buscando usuario ID: $usuario_id");

    if (!$usuario_id) {
        log_debug("      ⚠️ No hay usuario_id");
        return null;
    }

    $stmt = $conn->prepare("
        SELECT 
            id,
            ID_CLIENTE,
            ID_REGISTRO,
            NOMBRE_CLIENTE,
            NIT,
            CORREO,
            NOMBRE_USER,
            TIPO_ROL,
            ESTADO_USER
        FROM usuarios 
        WHERE id = ?
        LIMIT 1
    ");

    $stmt->bind_param("i", $usuario_id);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows > 0) {
        $usuario = $result->fetch_assoc();
        log_debug("   ✅ Usuario obtenido: " . ($usuario['NOMBRE_USER'] ?? 'N/A'));
        $stmt->close();
        return $usuario;
    }

    log_debug("   ❌ Usuario no encontrado");
    $stmt->close();
    return null;
}
