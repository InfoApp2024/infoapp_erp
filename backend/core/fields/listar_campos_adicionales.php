<?php
require_once '../../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../../conexion.php';
    
    // ✅ CONSULTA ACTUALIZADA con LEFT JOIN para obtener el nombre del estado
    $stmt = $conn->prepare("
        SELECT 
            ca.id,
            ca.modulo,
            ca.nombre_campo,
            ca.tipo_campo,
            ca.obligatorio,
            ca.estado_mostrar,
            ca.creado,
            ep.nombre_estado
        FROM campos_adicionales ca
        LEFT JOIN estados_proceso ep ON ca.estado_mostrar = ep.id
        ORDER BY ca.id DESC
    ");

    $stmt->execute();
    $result = $stmt->get_result();

    $campos = [];
    while ($row = $result->fetch_assoc()) {
        $campos[] = [
            'id' => $row['id'],
            'modulo' => $row['modulo'],
            'nombre_campo' => $row['nombre_campo'],
            'tipo_campo' => $row['tipo_campo'],
            'obligatorio' => intval($row['obligatorio']),
            'estado_mostrar' => $row['estado_mostrar'] ? intval($row['estado_mostrar']) : null,
            'nombre_estado' => $row['nombre_estado'], // ✅ NUEVO: Nombre del estado
            'creado' => $row['creado']
        ];
    }

    echo json_encode($campos);

} catch (Exception $e) {
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'campos' => []
    ]);
}

if (isset($stmt))
    $stmt->close();
if (isset($conn))
    $conn->close();
?>