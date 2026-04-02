<?php
// evidencias/listar.php - Listar evidencias de una inspección - Protegido con JWT

require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/inspecciones/evidencias/listar.php', 'view_evidences');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../../conexion.php';

    $inspeccion_id = isset($_GET['inspeccion_id']) ? (int) $_GET['inspeccion_id'] : null;
    $actividad_id = isset($_GET['actividad_id']) ? (int) $_GET['actividad_id'] : null;

    if (!$inspeccion_id) {
        throw new Exception('inspeccion_id es requerido');
    }

    // Construir WHERE clause
    $whereConditions = ["ie.inspeccion_id = ?"];
    $params = [$inspeccion_id];
    $types = "i";

    if ($actividad_id) {
        $whereConditions[] = "ie.actividad_id = ?";
        $params[] = $actividad_id;
        $types .= "i";
    }

    $whereClause = "WHERE " . implode(" AND ", $whereConditions);

    $sql = "SELECT 
                ie.id,
                ie.inspeccion_id,
                ie.actividad_id,
                ie.ruta_imagen,
                ie.comentario,
                ie.orden,
                ie.created_at,
                ie.updated_at,
                ie.created_by,
                
                u.NOMBRE_CLIENTE as creado_por_nombre,
                
                ia.actividad_id as actividad_estandar_id,
                ae.actividad as actividad_nombre
                
            FROM inspecciones_evidencias ie
            LEFT JOIN usuarios u ON ie.created_by = u.id
            LEFT JOIN inspecciones_actividades ia ON ie.actividad_id = ia.id
            LEFT JOIN actividades_estandar ae ON ia.actividad_id = ae.id
            $whereClause
            ORDER BY ie.orden ASC, ie.id ASC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);

    if (!$stmt->execute()) {
        throw new Exception("Error ejecutando query: " . $stmt->error);
    }

    $result = $stmt->get_result();
    $evidencias = [];

    while ($row = $result->fetch_assoc()) {
        $evidencias[] = [
            'id' => (int) $row['id'],
            'inspeccion_id' => (int) $row['inspeccion_id'],
            'actividad_id' => $row['actividad_id'] ? (int) $row['actividad_id'] : null,
            'actividad_nombre' => $row['actividad_nombre'] ?? null,
            'ruta_imagen' => $row['ruta_imagen'],
            'comentario' => $row['comentario'] ?? '',
            'orden' => (int) $row['orden'],
            'created_at' => $row['created_at'],
            'updated_at' => $row['updated_at'],
            'creado_por_nombre' => $row['creado_por_nombre'] ?? 'Desconocido'
        ];
    }

    sendJsonResponse([
        'success' => true,
        'data' => $evidencias,
        'total' => count($evidencias)
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
}

if (isset($conn)) {
    $conn->close();
}
?>