<?php
require_once '../../login/auth_middleware.php';

try {
    // Permitir acceso público a metadatos de campos (necesario para formularios públicos)
    $currentUser = optionalAuth();
    require '../../conexion.php';

    // Verificar parámetros
    if (!isset($_GET['estado_id'])) {
        throw new Exception('estado_id es requerido');
    }

    $estado_id = intval($_GET['estado_id']);
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'Servicios';

    if ($estado_id <= 0) {
        throw new Exception('estado_id debe ser mayor a 0');
    }

    // Consulta para obtener campos por estado
    $stmt = $conn->prepare("
        SELECT 
            ca.id,
            ca.nombre_campo,
            ca.tipo_campo,
            ca.obligatorio,
            ca.estado_mostrar,
            ca.modulo,
            ca.creado
        FROM campos_adicionales ca 
        WHERE ca.modulo = ?
        AND ca.estado_mostrar = ?
        ORDER BY ca.id ASC
    ");

    $stmt->bind_param("si", $modulo, $estado_id);
    $stmt->execute();
    $result = $stmt->get_result();

    // Procesar campos
    $camposProcesados = [];

    while ($campo = $result->fetch_assoc()) {
        $camposProcesados[] = [
            'id' => intval($campo['id']),
            'nombre_campo' => $campo['nombre_campo'],
            'tipo_campo' => $campo['tipo_campo'],
            'obligatorio' => intval($campo['obligatorio']),
            'estado_mostrar' => $campo['estado_mostrar'],
            'modulo' => $campo['modulo'],
            'creado' => $campo['creado']
        ];
    }

    // Respuesta exitosa
    $response = [
        'success' => true,
        'campos' => $camposProcesados,
        'total' => count($camposProcesados),
        'estado_id' => $estado_id,
        'modulo' => $modulo
    ];

    echo json_encode($response);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error obteniendo campos por estado: ' . $e->getMessage(),
        'campos' => [],
        'total' => 0
    ]);
}

if (isset($stmt))
    $stmt->close();
if (isset($conn))
    $conn->close();
?>