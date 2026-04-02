<?php
require_once '../login/auth_middleware.php';

try {
    // Permitir acceso público a estados (para selects en formularios públicos o privados)
    $currentUser = optionalAuth();
    require '../conexion.php';

    // Obtener el parámetro módulo con valor por defecto 'servicio'
    $modulo = isset($_GET['modulo']) ? trim($_GET['modulo']) : 'servicio';

    // Verificar conexión
    if ($conn->connect_errno) {
        throw new Exception('DB connection error');
    }

    // Configurar charset
    $conn->set_charset('utf8mb4');

    // ✅ NUEVO: Verificar si las columnas de estado_base existen
    $columnsExist = false;
    $checkColumns = $conn->query("SHOW COLUMNS FROM estados_proceso LIKE 'estado_base_codigo'");
    if ($checkColumns && $checkColumns->num_rows > 0) {
        $columnsExist = true;
    }

    // ✅ NUEVO: Verificar si la tabla estados_base existe
    $tableExists = false;
    $checkTable = $conn->query("SHOW TABLES LIKE 'estados_base'");
    if ($checkTable && $checkTable->num_rows > 0) {
        $tableExists = true;
    }

    // Preparar consulta con o sin estado base según disponibilidad
    if ($columnsExist && $tableExists) {
        // Versión completa con estado base
        $sql = 'SELECT 
            e.id,
            e.nombre_estado,
            e.color,
            e.modulo,
            e.estado_base_codigo,
            e.bloquea_cierre,
            eb.nombre as estado_base_nombre,
            eb.es_final as estado_base_es_final,
            eb.permite_edicion as estado_base_permite_edicion,
            e.orden
        FROM estados_proceso e
        LEFT JOIN estados_base eb ON e.estado_base_codigo = eb.codigo
        WHERE e.modulo = ?
        ORDER BY e.orden ASC, e.id ASC';
    } else {
        // Versión legacy sin estado base (retrocompatibilidad)
        $sql = 'SELECT 
            e.id,
            e.nombre_estado,
            e.color,
            e.modulo,
            e.orden
        FROM estados_proceso e
        WHERE e.modulo = ?
        ORDER BY e.orden ASC, e.id ASC';
    }

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('s', $modulo);
    $stmt->execute();
    $result = $stmt->get_result();

    $estados = [];
    while ($row = $result->fetch_assoc()) {
        // Asegurar valores por defecto para retrocompatibilidad
        if ($columnsExist) {
            if (!isset($row['estado_base_codigo']) || empty($row['estado_base_codigo'])) {
                $row['estado_base_codigo'] = 'ABIERTO';
            }
            if (!isset($row['bloquea_cierre'])) {
                $row['bloquea_cierre'] = 0;
            }
        }
        $estados[] = $row;
    }

    // Devolver respuesta con estructura consistente
    echo json_encode(['success' => true, 'data' => $estados]);

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