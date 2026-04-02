<?php
require_once '../../login/auth_middleware.php';

// Función de logging
function logMessage($message)
{
    // Usar la ruta absoluta o relativa a la raíz para los logs si es posible, o mantener local
    error_log(date('Y-m-d H:i:s') . " - OBTENER_VALORES: " . $message . "\n", 3, __DIR__ . "/obtener_valores.log");
}

try {
    // Permitir acceso público o autenticado
    $currentUser = optionalAuth();

    logMessage("=== INICIO OBTENER VALORES ===");

    // Verificar parámetros
    if (!isset($_GET['servicio_id'])) {
        throw new Exception('servicio_id es requerido');
    }

    $servicio_id = intval($_GET['servicio_id']);
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'Servicios';

    if ($servicio_id <= 0) {
        throw new Exception('servicio_id debe ser mayor a 0');
    }

    logMessage("Servicio ID: $servicio_id, Módulo: $modulo");

    // ✅ CONEXIÓN CORREGIDA (usar mysqli $conn como en el resto de la app)
    require '../../conexion.php';

    if (!isset($conn)) {
        throw new Exception('Error de conexión a la base de datos');
    }

    logMessage("Conexión establecida");

    // ✅ CONSULTA CORREGIDA - MySQLi
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
            vca.fecha_actualizacion as ultima_modificacion,
            ca.nombre_campo,
            ca.tipo_campo as campo_tipo_configurado,
            ca.obligatorio,
            ca.modulo
        FROM valores_campos_adicionales vca
        INNER JOIN campos_adicionales ca ON vca.campo_id = ca.id
        WHERE vca.servicio_id = ?
        ORDER BY ca.id ASC
    ";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Error preparando consulta: " . $conn->error);
    }

    $stmt->bind_param("i", $servicio_id);

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando consulta: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $valores = [];
    while ($row = $result->fetch_assoc()) {
        $valores[] = $row;
    }

    logMessage("Valores encontrados: " . count($valores));

    // Procesar valores según el tipo de campo
    $valoresProcesados = [];

    foreach ($valores as $valor) {
        $valorFinal = null;
        $tipoCampo = $valor['campo_tipo_configurado'];

        logMessage("Procesando campo ID {$valor['campo_id']}: {$valor['nombre_campo']} (tipo: $tipoCampo)");

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
                if ($valor['valor_texto'] !== null && $valor['valor_texto'] !== '') {
                    $valorFinal = $valor['valor_texto'];
                } elseif ($valor['valor_numero'] !== null) {
                    $valorFinal = $valor['valor_numero'];
                } elseif ($valor['valor_fecha'] !== null) {
                    $valorFinal = $valor['valor_fecha'];
                } elseif ($valor['valor_hora'] !== null) {
                    $valorFinal = $valor['valor_hora'];
                } elseif ($valor['valor_datetime'] !== null) {
                    $valorFinal = $valor['valor_datetime'];
                } elseif ($valor['valor_archivo'] !== null) {
                    $valorFinal = $valor['valor_archivo'];
                } elseif ($valor['valor_booleano'] !== null) {
                    $valorFinal = $valor['valor_booleano'] == 1;
                }
                break;
        }

        if ($valorFinal !== null && $valorFinal !== '') {
            $valoresProcesados[] = [
                'id' => intval($valor['id']),
                'campo_id' => intval($valor['campo_id']),
                'nombre_campo' => $valor['nombre_campo'],
                'tipo_campo' => $tipoCampo,
                'valor' => $valorFinal,
                'obligatorio' => intval($valor['obligatorio']),
                'fecha_creacion' => $valor['fecha_creacion'],
                'fecha_actualizacion' => $valor['fecha_actualizacion']
            ];
        }
    }

    // ✅ RESPUESTA EXITOSA
    $response = [
        'success' => true,
        'valores' => $valoresProcesados,
        'total' => count($valoresProcesados),
        'servicio_id' => $servicio_id,
        'modulo' => $modulo
    ];

    echo json_encode($response);
    logMessage("Respuesta enviada: " . count($valoresProcesados) . " valores");

} catch (Exception $e) {
    http_response_code(500);
    $errorMsg = 'Error obteniendo valores: ' . $e->getMessage();
    logMessage("ERROR: " . $errorMsg);

    echo json_encode([
        'success' => false,
        'message' => $errorMsg,
        'valores' => [],
        'total' => 0
    ]);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}

logMessage("=== FIN OBTENER VALORES ===\n");
?>