<?php
// actualizar.php - Actualizar inspección existente - Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/actualizar.php', 'update_inspection');

    if ($_SERVER['REQUEST_METHOD'] !== 'PUT' && $_SERVER['REQUEST_METHOD'] !== 'POST') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';
    require '../servicio/WebSocketNotifier.php';
    require 'helpers/inspeccion_helper.php';

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
        foreach (['inspectores', 'sistemas', 'actividades', 'notas_eliminacion'] as $key) {
            if (isset($input[$key]) && is_string($input[$key])) {
                $decoded = json_decode($input[$key], true);
                if (json_last_error() === JSON_ERROR_NONE) {
                    $input[$key] = $decoded;
                }
            }
        }
    }

    $inspeccion_id = $input['id'] ?? null;
    $estado_id = $input['estado_id'] ?? null;
    $sitio = $input['sitio'] ?? null;
    $fecha_inspe = $input['fecha_inspe'] ?? null;
    $equipo_id = $input['equipo_id'] ?? null;
    $inspectores = $input['inspectores'] ?? null;
    $sistemas = $input['sistemas'] ?? null;
    $actividades = $input['actividades'] ?? null;
    $notas_eliminacion = $input['notas_eliminacion'] ?? [];
    $usuario_id = $currentUser['id'];

    if (!$inspeccion_id) {
        throw new Exception('ID de inspección requerido');
    }

    // Verificar que la inspección existe y no esté en estado final
    $stmt_check = $conn->prepare("SELECT id, estado_id FROM inspecciones WHERE id = ? AND deleted_at IS NULL");
    $stmt_check->bind_param("i", $inspeccion_id);
    $stmt_check->execute();
    $result_check = $stmt_check->get_result();
    $inspeccion_actual = $result_check->fetch_assoc();

    if (!$inspeccion_actual) {
        throw new Exception('Inspección no encontrada');
    }

    if (esEstadoFinalInspeccion($conn, $inspeccion_actual['estado_id'])) {
        throw new Exception('La inspección se encuentra en estado final, cree una nueva inspección');
    }
    $stmt_check->close();

    // Iniciar transacción
    $conn->begin_transaction();

    try {
        // 1. Actualizar datos principales (solo los campos proporcionados)
        $updates = [];
        $params = [];
        $types = "";

        if ($estado_id !== null) {
            $updates[] = "estado_id = ?";
            $params[] = $estado_id;
            $types .= "i";
        }

        if ($sitio !== null) {
            $updates[] = "sitio = ?";
            $params[] = $sitio;
            $types .= "s";
        }

        if ($fecha_inspe !== null) {
            $updates[] = "fecha_inspe = ?";
            $params[] = $fecha_inspe;
            $types .= "s";
        }

        if ($equipo_id !== null) {
            $updates[] = "equipo_id = ?";
            $params[] = $equipo_id;
            $types .= "i";
        }

        // Siempre actualizar updated_by
        $updates[] = "updated_by = ?";
        $params[] = $usuario_id;
        $types .= "i";

        if (!empty($updates)) {
            $sql = "UPDATE inspecciones SET " . implode(", ", $updates) . " WHERE id = ?";
            $params[] = $inspeccion_id;
            $types .= "i";

            $stmt = $conn->prepare($sql);
            $stmt->bind_param($types, ...$params);

            if (!$stmt->execute()) {
                throw new Exception('Error actualizando inspección: ' . $stmt->error);
            }
            $stmt->close();
        }

        // 2. Actualizar inspectores si se proporcionaron
        if ($inspectores !== null && is_array($inspectores)) {
            // Eliminar inspectores existentes
            $stmt_del = $conn->prepare("DELETE FROM inspecciones_inspectores WHERE inspeccion_id = ?");
            $stmt_del->bind_param("i", $inspeccion_id);
            $stmt_del->execute();
            $stmt_del->close();

            // Insertar nuevos inspectores
            if (!empty($inspectores)) {
                $inspectores = array_unique($inspectores); // Eliminar duplicados
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
            }
        }

        // 3. Actualizar sistemas si se proporcionaron
        if ($sistemas !== null && is_array($sistemas)) {
            // Eliminar sistemas existentes
            $stmt_del = $conn->prepare("DELETE FROM inspecciones_sistemas WHERE inspeccion_id = ?");
            $stmt_del->bind_param("i", $inspeccion_id);
            $stmt_del->execute();
            $stmt_del->close();

            // Insertar nuevos sistemas
            if (!empty($sistemas)) {
                $sistemas = array_unique($sistemas); // Eliminar duplicados
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
            }
        }

        // 4. Actualizar actividades si se proporcionaron
        if ($actividades !== null && is_array($actividades)) {
            // Obtener actividades actuales
            $stmt_current = $conn->prepare("SELECT actividad_id FROM inspecciones_actividades WHERE inspeccion_id = ?");
            $stmt_current->bind_param("i", $inspeccion_id);
            $stmt_current->execute();
            $result_current = $stmt_current->get_result();
            $current_actividades = [];
            while ($row = $result_current->fetch_assoc()) {
                $current_actividades[] = (int) $row['actividad_id'];
            }
            $stmt_current->close();

            $actividades = array_unique(array_map('intval', $actividades));

            // Actividades a eliminar: están en DB pero no en la nueva lista
            $to_delete = array_diff($current_actividades, $actividades);
            if (!empty($to_delete)) {
                $stmt_soft_del = $conn->prepare("UPDATE inspecciones_actividades SET deleted_at = NOW(), notas = ? WHERE inspeccion_id = ? AND actividad_id = ?");
                foreach ($to_delete as $act_id) {
                    $nota = isset($notas_eliminacion[$act_id]) ? $notas_eliminacion[$act_id] : (isset($notas_eliminacion[(string) $act_id]) ? $notas_eliminacion[(string) $act_id] : 'Sin razón especificada');
                    $stmt_soft_del->bind_param("sii", $nota, $inspeccion_id, $act_id);
                    $stmt_soft_del->execute();
                }
                $stmt_soft_del->close();
            }

            // Actividades a agregar: están en la nueva lista pero no en DB (o estaban soft-deleted)
            $to_add = array_diff($actividades, $current_actividades);

            // También verificar si hay algunas en la lista nueva que están marcadas como deleted_at en el backend
            // y activarlas. Para simplificar, si el ID ya existe, lo "resucitamos".
            if (!empty($actividades)) {
                $placeholders = implode(',', array_fill(0, count($actividades), '?'));
                $sql_resurrect = "UPDATE inspecciones_actividades SET deleted_at = NULL, notas = '' WHERE inspeccion_id = ? AND actividad_id IN ($placeholders)";
                $stmt_res = $conn->prepare($sql_resurrect);
                $types = "i" . str_repeat("i", count($actividades));
                $params = array_merge([$inspeccion_id], array_values($actividades));
                $stmt_res->bind_param($types, ...$params);
                $stmt_res->execute();
                $stmt_res->close();
            }

            // Actividades a agregar: están en la nueva lista pero no en DB
            $to_add = array_diff($actividades, $current_actividades);
            if (!empty($to_add)) {
                $stmt_add = $conn->prepare("INSERT INTO inspecciones_actividades (inspeccion_id, actividad_id, created_by) VALUES (?, ?, ?)");
                foreach ($to_add as $actividad_id) {
                    $stmt_add->bind_param("iii", $inspeccion_id, $actividad_id, $usuario_id);
                    if (!$stmt_add->execute()) {
                        throw new Exception('Error añadiendo actividad: ' . $stmt_add->error);
                    }
                }
                $stmt_add->close();
            }
        }

        // 5. Procesar Evidencias (Archivos) - Solo agregar nuevas
        if (isset($_FILES['evidencias'])) {
            $evidencias_info = [];
            if (isset($input['evidencias_info'])) {
                $evidencias_info = is_string($input['evidencias_info'])
                    ? json_decode($input['evidencias_info'], true)
                    : $input['evidencias_info'];
            }

            // Obtener o_inspe para nombrar archivos
            $stmt_o_inspe = $conn->prepare("SELECT o_inspe FROM inspecciones WHERE id = ?");
            $stmt_o_inspe->bind_param("i", $inspeccion_id);
            $stmt_o_inspe->execute();
            $result_o_inspe = $stmt_o_inspe->get_result();
            $row_o_inspe = $result_o_inspe->fetch_assoc();
            $o_inspe = $row_o_inspe['o_inspe'] ?? 'INS-' . $inspeccion_id;
            $stmt_o_inspe->close();

            $uploadDir = '../uploads/inspecciones/' . date('Y/m') . '/';
            if (!file_exists($uploadDir)) {
                mkdir($uploadDir, 0777, true);
            }

            $stmt_evidencia = $conn->prepare(
                "INSERT INTO inspecciones_evidencias (inspeccion_id, ruta_imagen, comentario, actividad_id, created_by) VALUES (?, ?, ?, ?, ?)"
            );

            $files = $_FILES['evidencias'];
            $fileCount = is_array($files['name']) ? count($files['name']) : 0;

            for ($i = 0; $i < $fileCount; $i++) {
                if ($files['error'][$i] === UPLOAD_ERR_OK) {
                    $tmpName = $files['tmp_name'][$i];
                    $originalName = $files['name'][$i];

                    $extension = pathinfo($originalName, PATHINFO_EXTENSION);
                    $newFileName = $o_inspe . '_EVID_' . uniqid() . '.' . $extension;
                    $targetPath = $uploadDir . $newFileName;
                    $dbPath = 'uploads/inspecciones/' . date('Y/m') . '/' . $newFileName;

                    if (move_uploaded_file($tmpName, $targetPath)) {
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
                            error_log("Error guardando evidencia $originalName: " . $stmt_evidencia->error);
                        }
                    }
                }
            }
            $stmt_evidencia->close();
        }

        // 6. Verificar si la inspección debe finalizarse tras los cambios
        $resultado_finalizacion = verificarYFinalizarInspeccion($conn, $inspeccion_id, $usuario_id);

        // Commit de la transacción
        $conn->commit();

        // Notificar vía WebSocket
        try {
            $notifier = new WebSocketNotifier();
            $notifier->notificar([
                'tipo' => 'inspeccion_actualizada',
                'inspeccion_id' => $inspeccion_id,
                'usuario_id' => $usuario_id
            ]);
        } catch (Exception $ws_error) {
            error_log("WebSocket error: " . $ws_error->getMessage());
        }

        // Respuesta exitosa
        sendJsonResponse([
            'success' => true,
            'message' => $resultado_finalizacion['finalizada']
                ? 'Inspección finalizada automáticamente. Cree una nueva para continuar.'
                : 'Inspección actualizada exitosamente',
            'data' => [
                'id' => (int) $inspeccion_id,
                'inspeccion_finalizada' => $resultado_finalizacion['finalizada'],
                'nuevo_estado_id' => $resultado_finalizacion['nuevo_estado_id'] ?? null
            ]
        ]);

    } catch (Exception $e) {
        $conn->rollback();
        throw $e;
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 400);
} finally {
    if (isset($conn))
        $conn->close();
}
?>