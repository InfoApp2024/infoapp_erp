<?php
require_once __DIR__ . '/../login/auth_middleware.php';

try {
    // Permitir acceso público o autenticado
    $currentUser = optionalAuth();
    require __DIR__ . '/../conexion.php';

    // Obtener el parámetro módulo con valor por defecto 'servicio'
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'servicio';

    // Verificar conexión
    if ($conn->connect_errno) {
        throw new Exception('DB connection error');
    }

    // Configurar charset
    $conn->set_charset('utf8mb4');

    // Preparar consulta con filtro por módulo y obtener nombres de estados
    $stmt = $conn->prepare('
        SELECT t.id, t.estado_origen_id, eo.nombre_estado AS nombre_origen, 
               t.estado_destino_id, ed.nombre_estado AS nombre_destino,
               t.nombre, t.trigger_code
        FROM transiciones_estado t
        LEFT JOIN estados_proceso eo ON t.estado_origen_id = eo.id
        LEFT JOIN estados_proceso ed ON t.estado_destino_id = ed.id
        WHERE t.modulo = ? 
        ORDER BY t.id ASC
    ');
    $stmt->bind_param('s', $modulo);
    $stmt->execute();
    $result = $stmt->get_result();

    $transiciones = [];
    while ($row = $result->fetch_assoc()) {
        $transiciones[] = $row;
    }

    // Devolver respuesta con estructura consistente
    echo json_encode(['success' => true, 'data' => $transiciones]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
?>