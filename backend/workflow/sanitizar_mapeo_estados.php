<?php
/**
 * SCRIPT: sanitizar_mapeo_estados.php
 * PROPÓSITO: Corregir el mapeo de estado_base_codigo basado en el nombre del estado.
 */

require_once __DIR__ . '/../conexion.php';

header('Content-Type: application/json');

try {
    $conn->begin_transaction();

    $mappings = [
        'ABIERTO' => ['ABIERTO', 'OPEN'],
        'PROGRAMADO' => ['PROGRAMAD'],
        'ASIGNADO' => ['ASIGNAD'],
        'EN_EJECUCION' => ['EJECUCI', 'ATENDID', 'PROCESO'],
        'FINALIZADO' => ['FINALIZA', 'TERMINAD'],
        'CERRADO' => ['CERRAD', 'CIERRE'],
        'CANCELADO' => ['CANCELA', 'ANULAD']
    ];

    $updatedCount = 0;

    foreach ($mappings as $code => $patterns) {
        foreach ($patterns as $pattern) {
            $sql = "UPDATE estados_proceso 
                    SET estado_base_codigo = '$code' 
                    WHERE (nombre_estado LIKE '%$pattern%' OR estado_base_codigo IS NULL OR estado_base_codigo = 'ABIERTO')
                    AND modulo = 'servicio'";

            // Especial: Si ya tiene un código base distinto de ABIERTO, no lo sobrescribimos a menos que sea el patrón exacto
            if ($code !== 'ABIERTO') {
                $sql .= " AND (estado_base_codigo = 'ABIERTO' OR estado_base_codigo IS NULL)";
            }

            if ($conn->query($sql)) {
                $updatedCount += $conn->affected_rows;
            }
        }
    }

    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => "Sanitización completada.",
        'filas_actualizadas' => $updatedCount
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