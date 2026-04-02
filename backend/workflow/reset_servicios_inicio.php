<?php
/**
 * SCRIPT: reset_servicios_inicio.php
 * PROPÓSITO: Mover todos los servicios al estado "Abierto" para permitir limpieza de estados antiguos.
 */

require_once __DIR__ . '/../conexion.php';

header('Content-Type: application/json');

try {
    $conn->begin_transaction();

    // 1. Encontrar el ID oficial del estado "Abierto" para servicios
    $sqlAbierto = "SELECT id FROM estados_proceso WHERE nombre_estado = 'Abierto' AND modulo = 'servicio' LIMIT 1";
    $resAbierto = $conn->query($sqlAbierto);

    if ($resAbierto->num_rows === 0) {
        throw new Exception("No se encontró el estado 'Abierto' oficial. Ejecuta primero reparacion_final_mapeo.php");
    }

    $abiertoId = $resAbierto->fetch_assoc()['id'];

    // 2. Mover todos los servicios a ese estado
    $updateServicios = "UPDATE servicio SET estado_id = $abiertoId";
    $conn->query($updateServicios);
    $serviciosMovidos = $conn->affected_rows;

    // 3. (Opcional) Limpiar transiciones antiguas para empezar de cero
    // NOTA: Esto borrará el diagrama actual. El usuario dijo "luego con los estados nuevos".
    // $conn->query("DELETE FROM transiciones_estado WHERE modulo = 'servicio'");

    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => "Reinicio completado exitosamente.",
        'detalles' => [
            'estado_abierto_id' => $abiertoId,
            'servicios_reseteados' => $serviciosMovidos,
            'instrucciones' => "Ahora puedes ir a la App y eliminar los estados de usuario sobrantes."
        ]
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    if ($conn)
        $conn->rollback();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => "Error: " . $e->getMessage()
    ]);
}
?>