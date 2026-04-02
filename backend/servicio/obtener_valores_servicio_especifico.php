<?php
// header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require '../conexion.php';
require '../auth_middleware.php';

try {
    $user_data = requireAuth();

    if (!isset($_GET['servicio_id'])) {
        throw new Exception('servicio_id es requerido');
    }

    $servicio_id = intval($_GET['servicio_id']);
    $campo_ids = isset($_GET['campo_ids']) ? $_GET['campo_ids'] : null;

    if ($servicio_id <= 0) {
        throw new Exception('servicio_id debe ser mayor a 0');
    }

    // require '../conexion.php';

    // Construir consulta con filtro opcional de campos específicos
    $sqlBase = "
        SELECT 
            vca.campo_id,
            vca.valor_texto,
            vca.valor_numero,
            vca.valor_fecha,
            vca.valor_hora,
            vca.valor_datetime,
            vca.valor_archivo,
            vca.valor_booleano,
            ca.tipo_campo,
            GREATEST(
                IFNULL(vca.fecha_actualizacion, vca.fecha_creacion),
                vca.fecha_creacion
            ) as ultima_modificacion
        FROM valores_campos_adicionales vca
        INNER JOIN campos_adicionales ca ON vca.campo_id = ca.id
        WHERE vca.servicio_id = ?
    ";

    $params = [$servicio_id];

    // Agregar filtro de campos específicos si se proporcionan
    if ($campo_ids) {
        $campoIdsArray = explode(',', $campo_ids);
        $campoIdsArray = array_map('intval', $campoIdsArray);
        $campoIdsArray = array_filter($campoIdsArray, function ($id) {
            return $id > 0;
        });

        if (!empty($campoIdsArray)) {
            $placeholders = str_repeat('?,', count($campoIdsArray) - 1) . '?';
            $sqlBase .= " AND vca.campo_id IN ($placeholders)";
            $params = array_merge($params, $campoIdsArray);
        }
    }

    $sqlBase .= " ORDER BY vca.campo_id";

    $stmt = $pdo->prepare($sqlBase);
    $stmt->execute($params);
    $valores = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Procesar valores de forma optimizada
    $valoresProcesados = [];
    $ultimaModificacion = null;

    foreach ($valores as $valor) {
        $campoId = intval($valor['campo_id']);
        $tipoCampo = $valor['tipo_campo'];
        $valorFinal = null;

        // Lógica optimizada de procesamiento
        switch ($tipoCampo) {
            case 'Texto':
            case 'Párrafo':
            case 'Link':
                $valorFinal = $valor['valor_texto'];
                break;
            case 'Entero':
                $valorFinal = $valor['valor_numero'] !== null ? intval($valor['valor_numero']) : null;
                break;
            case 'Decimal':
            case 'Moneda':
                $valorFinal = $valor['valor_numero'] !== null ? floatval($valor['valor_numero']) : null;
                break;
            case 'Fecha':
                $valorFinal = $valor['valor_fecha'];
                break;
            case 'Hora':
                $valorFinal = $valor['valor_hora'];
                break;
            case 'Datetime':
            case 'Fecha y hora':
                $valorFinal = $valor['valor_datetime'];
                break;
            case 'Imagen':
            case 'Archivo':
                $valorFinal = $valor['valor_archivo'];
                break;
            case 'Booleano':
                $valorFinal = $valor['valor_booleano'] == 1;
                break;
            default:
                $valorFinal = $valor['valor_texto'] ?: $valor['valor_numero'] ?: $valor['valor_fecha'];
                break;
        }

        if ($valorFinal !== null && $valorFinal !== '') {
            $valoresProcesados[$campoId] = $valorFinal;
        }

        // Tracking de última modificación
        if (
            $valor['ultima_modificacion'] &&
            (!$ultimaModificacion || $valor['ultima_modificacion'] > $ultimaModificacion)
        ) {
            $ultimaModificacion = $valor['ultima_modificacion'];
        }
    }

    echo json_encode([
        'success' => true,
        'valores' => $valoresProcesados,
        'total' => count($valoresProcesados),
        'ultima_modificacion' => $ultimaModificacion,
        'servicio_id' => $servicio_id,
        'campos_solicitados' => $campo_ids
    ]);
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error obteniendo valores específicos: ' . $e->getMessage(),
        'valores' => []
    ]);
}
