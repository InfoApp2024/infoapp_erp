<?php
require_once '../../login/auth_middleware.php';

// Asegurar headers CORS desde el inicio
if (function_exists('setCORSHeaders')) {
    setCORSHeaders();
}

try {
    $currentUser = requireAuth();
    require '../../conexion.php';

    if (!isset($conn)) {
        throw new Exception('Error de conexión a la base de datos');
    }

    // Solo obtener estructura de campos, NO valores
    $sql = "SELECT 
                ca.id,
                ca.nombre_campo,
                ca.tipo_campo,
                ca.obligatorio,
                ca.modulo,
                ca.estado_mostrar
            FROM campos_adicionales ca
            ORDER BY ca.estado_mostrar, ca.id";

    $result = $conn->query($sql);

    if (!$result) {
        throw new Exception('Error ejecutando consulta: ' . $conn->error);
    }

    $camposPorEstado = [];
    $totalCampos = 0;

    while ($row = $result->fetch_assoc()) {
        $estadoId = $row['estado_mostrar'] ?? 0;
        if (!isset($camposPorEstado[$estadoId])) {
            $camposPorEstado[$estadoId] = [];
        }
        $camposPorEstado[$estadoId][] = [
            'id' => intval($row['id']),
            'nombre_campo' => $row['nombre_campo'],
            'tipo_campo' => $row['tipo_campo'],
            'obligatorio' => intval($row['obligatorio']),
            'modulo' => $row['modulo'],
            'orden' => 0 // Orden no existe en DB, defaulting a 0
        ];
        $totalCampos++;
    }

    echo json_encode([
        'success' => true,
        'campos_por_estado' => $camposPorEstado,
        'total_campos' => $totalCampos,
        'timestamp' => date('Y-m-d H:i:s')
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error obteniendo metadatos: ' . $e->getMessage()
    ]);
} finally {
    if (isset($conn) && $conn) {
        $conn->close();
    }
}
?>