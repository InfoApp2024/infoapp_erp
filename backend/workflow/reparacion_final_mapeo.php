<?php
/**
 * SCRIPT: reparacion_final_mapeo.php
 * PROPÓSITO: Corregir de forma definitiva y agresiva el mapeo de los 7 estados core.
 */

require_once __DIR__ . '/../conexion.php';

header('Content-Type: application/json');

try {
    $conn->begin_transaction();

    // Reglas estrictas: Si se llama así, DEBE ser este código
    $strictRules = [
        'ABIERTO' => ['Abierto'],
        'PROGRAMADO' => ['Programado', 'Programada'],
        'ASIGNADO' => ['Asignado', 'Asignada'],
        'EN_EJECUCION' => ['En Ejecución', 'Atendido', 'En Proceso'],
        'FINALIZADO' => ['Finalizado'],
        'CERRADO' => ['Cerrado'],
        'CANCELADO' => ['Cancelado']
    ];

    $results = [];

    foreach ($strictRules as $code => $names) {
        foreach ($names as $name) {
            $stmt = $conn->prepare("UPDATE estados_proceso SET estado_base_codigo = ? WHERE nombre_estado = ? AND modulo = 'servicio'");
            $stmt->bind_param("ss", $code, $name);
            $stmt->execute();

            if ($stmt->affected_rows > 0) {
                $results[] = "Actualizado '$name' a '$code' ({$stmt->affected_rows} filas)";
            }
            $stmt->close();
        }
    }

    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => "Reparación completada.",
        'detalles' => $results
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