<?php
require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../../conexion.php';

    // Total de servicios activos
    $sqlTotal = "SELECT COUNT(*) as total FROM servicios WHERE (anular_servicio = 0 OR anular_servicio IS NULL)";
    $resultTotal = $conn->query($sqlTotal);
    $total = $resultTotal ? $resultTotal->fetch_assoc()['total'] : 0;

    // Estados únicos
    $sqlEstados = "
        SELECT DISTINCT e.nombre_estado 
        FROM servicios s 
        LEFT JOIN estados_proceso e ON s.estado = e.id 
        WHERE (s.anular_servicio = 0 OR s.anular_servicio IS NULL)
        AND e.nombre_estado IS NOT NULL
        ORDER BY e.nombre_estado
    ";
    $resultEstados = $conn->query($sqlEstados);
    $estados = [];
    if ($resultEstados) {
        while ($row = $resultEstados->fetch_assoc()) {
            $estados[] = $row['nombre_estado'];
        }
    }

    // Tipos únicos
    $sqlTipos = "
        SELECT DISTINCT tipo_mantenimiento 
        FROM servicios 
        WHERE (anular_servicio = 0 OR anular_servicio IS NULL)
        AND tipo_mantenimiento IS NOT NULL 
        AND tipo_mantenimiento != ''
        ORDER BY tipo_mantenimiento
    ";
    $resultTipos = $conn->query($sqlTipos);
    $tipos = [];
    if ($resultTipos) {
        while ($row = $resultTipos->fetch_assoc()) {
            $tipos[] = $row['tipo_mantenimiento'];
        }
    }

    echo json_encode([
        'success' => true,
        'data' => [
            'total_servicios' => (int) $total,
            'estados_disponibles' => $estados,
            'tipos_disponibles' => $tipos
        ]
    ]);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => 'Error: ' . $e->getMessage()
    ]);
}

$conn->close();
?>