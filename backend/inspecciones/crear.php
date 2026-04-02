<?php
// crear.php - Crear nueva inspección - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/crear.php', 'create_inspection');

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';
    require '../servicio/WebSocketNotifier.php';

    // Detectar tipo de contenido para procesar input
    $contentType = $_SERVER['CONTENT_TYPE'] ?? '';
    $input = [];

    if (strpos($contentType, 'application/json') !== false) {
        $raw_input = file_get_contents('php://input');
        $input = json_decode($raw_input, true);
        if (!$input || json_last_error() !== JSON_ERROR_NONE) {
            throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
        }
    } else {
        // Asumir multipart/form-data o x-www-form-urlencoded
        $input = $_POST;

        // Decodificar campos JSON que vienen como strings en multipart
        foreach (['inspectores', 'sistemas', 'actividades'] as $key) {
            if (isset($input[$key]) && is_string($input[$key])) {
                $decoded = json_decode($input[$key], true);
                if (json_last_error() === JSON_ERROR_NONE) {
                    $input[$key] = $decoded;
                }
            }
        }
    }

    // Extraer datos del input
    $estado_id = $input['estado_id'] ?? null;
    $sitio = $input['sitio'] ?? 'PLANTA';
    $fecha_inspe = $input['fecha_inspe'] ?? date('Y-m-d');
    $equipo_id = $input['equipo_id'] ?? null;
    $inspectores = $input['inspectores'] ?? []; // Array de IDs de usuarios
    $sistemas = $input['sistemas'] ?? []; // Array de IDs de sistemas
    $actividades = $input['actividades'] ?? []; // Array de IDs de actividades
    $usuario_id = $currentUser['id'];

    // Validaciones
    $errores = [];
    if (!$estado_id)
        $errores[] = 'estado_id';
    if (!$sitio)
        $errores[] = 'sitio';
    if (!$fecha_inspe)
        $errores[] = 'fecha_inspe';
    if (!$equipo_id)
        $errores[] = 'equipo_id';
    if (empty($inspectores))
        $errores[] = 'inspectores (debe haber al menos uno)';
    if (empty($sistemas))
        $errores[] = 'sistemas (debe haber al menos uno)';
    if (empty($actividades))
        $errores[] = 'actividades (debe haber al menos una)';

    if (!empty($errores)) {
        throw new Exception('Campos faltantes: ' . implode(', ', $errores));
    }

    // Iniciar transacción
    $conn->begin_transaction();

    try {
        // 1. Generar o_inspe desde PHP (Evitamos dependencia de Triggers)
        $year_month = date('Ym', strtotime($fecha_inspe));
        $stmt_count = $conn->prepare("SELECT COUNT(*) as total FROM inspecciones WHERE DATE_FORMAT(fecha_inspe, '%Y%m') = ?");
        if (!$stmt_count) {
            throw new Exception("Error preparando contador: " . $conn->error);
        }
        $stmt_count->bind_param("s", $year_month);
        $stmt_count->execute();
        $res_count = $stmt_count->get_result();
        $row_count = $res_count->fetch_assoc();
        $next_id = ($row_count['total'] ?? 0) + 1;
        $stmt_count->close();

        $o_inspe = "INS-$year_month-" . str_pad($next_id, 4, '0', STR_PAD_LEFT);

        // 2. Insertar inspección principal
        $sql = "INSERT INTO inspecciones (
                    o_inspe, estado_id, sitio, fecha_inspe, equipo_id, 
                    created_by, updated_by
                ) VALUES (?, ?, ?, ?, ?, ?, ?)";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Error preparando query inspección: ' . $conn->error);
        }

        $stmt->bind_param(
            "sissiii",
            $o_inspe,
            $estado_id,
            $sitio,
            $fecha_inspe,
            $equipo_id,
            $usuario_id,
            $usuario_id
        );

        if (!$stmt->execute()) {
            throw new Exception('Error creando inspección: ' . $stmt->error);
        }

        $inspeccion_id = $conn->insert_id;

        // o_inspe ya lo tenemos calculado
        // $stmt_o_inspe = $conn->prepare("SELECT o_inspe FROM inspecciones WHERE id = ?"); ... eliminamos esto

        // 2. Insertar inspectores
        $stmt_inspector = $conn->prepare(
            "INSERT INTO inspecciones_inspectores (inspeccion_id, usuario_id, rol_inspector) VALUES (?, ?, ?)"
        );

        foreach ($inspectores as $index => $inspector_id) {
            $rol = $index === 0 ? 'Principal' : 'Asistente';
            $stmt_inspector->bind_param("iis", $inspeccion_id, $inspector_id, $rol);
            if (!$stmt_inspector->execute()) {
                throw new Exception('Error asignando inspector: ' . $stmt_inspector->error);
            }
        }
        $stmt_inspector->close();

        // 3. Insertar sistemas
        $stmt_sistema = $conn->prepare(
            "INSERT INTO inspecciones_sistemas (inspeccion_id, sistema_id) VALUES (?, ?)"
        );

        foreach ($sistemas as $sistema_id) {
            $stmt_sistema->bind_param("ii", $inspeccion_id, $sistema_id);
            if (!$stmt_sistema->execute()) {
                throw new Exception('Error asignando sistema: ' . $stmt_sistema->error);
            }
        }
        $stmt_sistema->close();

        // 4. Insertar actividades
        $stmt_actividad = $conn->prepare(
            "INSERT INTO inspecciones_actividades (inspeccion_id, actividad_id, created_by) VALUES (?, ?, ?)"
        );

        foreach ($actividades as $actividad_id) {
            $stmt_actividad->bind_param("iii", $inspeccion_id, $actividad_id, $usuario_id);
            if (!$stmt_actividad->execute()) {
                throw new Exception('Error asignando actividad: ' . $stmt_actividad->error);
            }
        }
        $stmt_actividad->close();

        // 5. Procesar Evidencias (Archivos)
        if (isset($_FILES['evidencias'])) {
            $evidencias_info = [];
            if (isset($input['evidencias_info'])) {
                $evidencias_info = is_string($input['evidencias_info'])
                    ? json_decode($input['evidencias_info'], true)
                    : $input['evidencias_info'];
            }

            $uploadDir = '../uploads/inspecciones/' . date('Y/m') . '/';
            if (!file_exists($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            $stmt_evidencia = $conn->prepare(
                "INSERT INTO inspecciones_evidencias (inspeccion_id, ruta_imagen, comentario, actividad_id, created_by) VALUES (?, ?, ?, ?, ?)"
            );

            // Manejar array de archivos
            $files = $_FILES['evidencias'];
            $fileCount = is_array($files['name']) ? count($files['name']) : 0;

            for ($i = 0; $i < $fileCount; $i++) {
                if ($files['error'][$i] === UPLOAD_ERR_OK) {
                    $tmpName = $files['tmp_name'][$i];
                    $originalName = $files['name'][$i];

                    $extension = pathinfo($originalName, PATHINFO_EXTENSION);
                    $newFileName = $o_inspe . '_EVID_' . uniqid() . '.' . $extension;
                    $targetPath = $uploadDir . $newFileName;

                    // Ruta relativa para guardar en BD (ajustar según como la sirvas)
                    // Asumimos que se sirve desde la raíz o configurado alias
                    $dbPath = 'uploads/inspecciones/' . date('Y/m') . '/' . $newFileName;

                    if (move_uploaded_file($tmpName, $targetPath)) {
                        // Buscar metadata
                        $comentario = '';
                        $actividad_id = null;
                        if (!empty($evidencias_info)) {
                            foreach ($evidencias_info as $info) {
                                if ($info['filename'] === $originalName) {
                                    $comentario = $info['comentario'] ?? '';
                                    $actividad_id = isset($info['actividad_id']) ? (int) $info['actividad_id'] : null;
                                    break;
                                }
                            }
                        }

                        $stmt_evidencia->bind_param("isssi", $inspeccion_id, $dbPath, $comentario, $actividad_id, $usuario_id);
                        if (!$stmt_evidencia->execute()) {
                            // No detener todo por una imagen fallida, pero logear
                            error_log("Error guardando evidencia $originalName: " . $stmt_evidencia->error);
                        }
                    }
                }
            }
            $stmt_evidencia->close();
        }

        // Commit de la transacción
        $conn->commit();

        // Notificar vía WebSocket
        try {
            $notifier = new WebSocketNotifier();
            $notifier->notificar([
                'tipo' => 'inspeccion_creada',
                'inspeccion_id' => $inspeccion_id,
                'o_inspe' => $o_inspe,
                'usuario_id' => $usuario_id
            ]);
        } catch (Exception $ws_error) {
            // No fallar si el WebSocket falla
            error_log("WebSocket error: " . $ws_error->getMessage());
        }

        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => 'Inspección creada exitosamente',
            'data' => [
                'id' => (int) $inspeccion_id,
                'o_inspe' => $o_inspe,
                'estado_id' => (int) $estado_id,
                'sitio' => $sitio,
                'fecha_inspe' => $fecha_inspe,
                'equipo_id' => (int) $equipo_id,
                'total_inspectores' => count($inspectores),
                'total_sistemas' => count($sistemas),
                'total_actividades' => count($actividades)
            ]
        ], 201);

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>