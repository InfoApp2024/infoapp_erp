<?php
require_once '../../login/auth_middleware.php';

try {
    // Configurar CORS y Auth opcional
    $currentUser = optionalAuth();

    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit;
    }

    // Función de logging
    function logMessage($message)
    {
        error_log(date('Y-m-d H:i:s') . " - BATCH_CAMPOS: " . $message . "\n", 3, __DIR__ . "/obtener_valores_batch.log");
    }

    logMessage("=== INICIO BATCH CAMPOS (OPTIMIZADO) ===");

    require '../../conexion.php';
    if (!isset($conn)) {
        throw new Exception('Error de conexión a la base de datos');
    }

    // Leer el body JSON
    $input = json_decode(file_get_contents('php://input'), true);
    if (!isset($input['servicio_ids']) || !is_array($input['servicio_ids'])) {
        throw new Exception('servicio_ids requerido');
    }

    // Filtrar IDs inválidos y eliminar duplicados
    $servicioIds = array_unique(array_map('intval', $input['servicio_ids']));
    $servicioIds = array_filter($servicioIds, function ($id) {
        return $id > 0; });

    // Re-indexar array para evitar problemas al iterar
    $servicioIds = array_values($servicioIds);

    $modulo = isset($input['modulo']) ? trim($input['modulo']) : 'Servicios';

    logMessage("Servicios solicitados: " . count($servicioIds) . ", Módulo: $modulo");

    // Inicializar resultado vacío para todos los IDs solicitados
    $resultado = [];
    foreach ($servicioIds as $id) {
        $resultado[$id] = [];
    }

    if (empty($servicioIds)) {
        logMessage("No hay IDs válidos para procesar");
    } else {
        // --- CONSULTA OPTIMIZADA (IN CLAUSE) ---

        // Crear placeholders (?,?,?)
        $placeholders = implode(',', array_fill(0, count($servicioIds), '?'));

        $sql = "
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
                GREATEST(
                    IFNULL(vca.fecha_ultima_modificacion, vca.fecha_creacion),
                    vca.fecha_creacion
                ) as ultima_modificacion,
                ca.nombre_campo,
                ca.tipo_campo as campo_tipo_configurado,
                ca.obligatorio,
                ca.modulo
            FROM valores_campos_adicionales vca
            INNER JOIN campos_adicionales ca ON vca.campo_id = ca.id
            WHERE vca.servicio_id IN ($placeholders)
            ORDER BY vca.servicio_id, ca.id ASC
        ";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception("Error preparing statement: " . $conn->error);
        }

        // Bind dinámico de parámetros
        $types = str_repeat('i', count($servicioIds));
        $params = array_merge([$types], $servicioIds);

        // Usar Reflection o call_user_func_array para bind_param dinámico
        $tmpParams = [];
        foreach ($params as $key => $value) {
            $tmpParams[$key] = &$params[$key];
        }
        call_user_func_array([$stmt, 'bind_param'], $tmpParams);

        if (!$stmt->execute()) {
            throw new Exception("Error executing statement: " . $stmt->error);
        }

        $result = $stmt->get_result();

        // Procesar todos los resultados en un solo loop
        while ($row = $result->fetch_assoc()) {
            $servicio_id = intval($row['servicio_id']);

            $valorFinal = null;
            $tipoCampo = $row['campo_tipo_configurado'];

            switch ($tipoCampo) {
                case 'Texto':
                case 'Párrafo':
                case 'Link':
                    $valorFinal = $row['valor_texto'];
                    break;
                case 'Entero':
                    $valorFinal = $row['valor_numero'] !== null ? intval($row['valor_numero']) : null;
                    break;
                case 'Decimal':
                case 'Moneda':
                    $valorFinal = $row['valor_numero'] !== null ? floatval($row['valor_numero']) : null;
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
                    if ($row['valor_texto'] !== null && $row['valor_texto'] !== '') {
                        $valorFinal = $row['valor_texto'];
                    } elseif ($row['valor_numero'] !== null) {
                        $valorFinal = $row['valor_numero'];
                    } elseif ($row['valor_fecha'] !== null) {
                        $valorFinal = $row['valor_fecha'];
                    } elseif ($row['valor_hora'] !== null) {
                        $valorFinal = $row['valor_hora'];
                    } elseif ($row['valor_datetime'] !== null) {
                        $valorFinal = $row['valor_datetime'];
                    } elseif ($row['valor_archivo'] !== null) {
                        $valorFinal = $row['valor_archivo'];
                    } elseif ($row['valor_booleano'] !== null) {
                        $valorFinal = $row['valor_booleano'] == 1;
                    }
                    break;
            }

            if ($valorFinal !== null && $valorFinal !== '') {
                $resultado[$servicio_id][] = [
                    'id' => intval($row['id']),
                    'campo_id' => intval($row['campo_id']),
                    'nombre_campo' => $row['nombre_campo'],
                    'tipo_campo' => $tipoCampo,
                    'valor' => $valorFinal,
                    'obligatorio' => intval($row['obligatorio']),
                    'fecha_creacion' => $row['fecha_creacion'],
                    'fecha_actualizacion' => $row['fecha_actualizacion']
                ];
            }
        }
        $stmt->close();
    } // fin if empty servicioIds

    if (isset($conn))
        $conn->close();

    logMessage("Procesamiento completado. Total servicios: " . count($resultado));

    // Respuesta exitosa
    $response = [
        'success' => true,
        'data' => $resultado,
        'total_servicios' => count($resultado),
        'modulo' => $modulo
    ];
    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    $errorMsg = 'Error batch: ' . $e->getMessage();

    if (function_exists('logMessage')) {
        logMessage("ERROR: " . $errorMsg);
        logMessage("Stack trace: " . $e->getTraceAsString());
    } else {
        error_log($errorMsg);
    }

    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'data' => [],
        'total_servicios' => 0
    ]);
}

if (function_exists('logMessage'))
    logMessage("=== FIN BATCH CAMPOS ===\n");
?>