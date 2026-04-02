<?php
/**
 * accounting_phase_14_snapshot_fix.php
 * Wrapper para ejecutar la migración SQL de corrección del esquema de Snapshot.
 */

try {
    require_once __DIR__ . '/../conexion.php';

    $sqlPath = __DIR__ . '/accounting_phase_14_snapshot_fix.sql';
    
    if (!file_exists($sqlPath)) {
        throw new Exception("No se encontró el archivo SQL de migración: $sqlPath");
    }

    $sql = file_get_contents($sqlPath);
    
    // No usamos multi_query para tener control total de errores por comando
    $commands = array_filter(array_map('trim', explode(';', $sql)));
    
    $queriesExecuted = 0;
    foreach ($commands as $cmd) {
        if (empty($cmd)) continue;
        if (!$conn->query($cmd)) {
            throw new Exception("Error ejecutando comando SQL: " . $conn->error . "\nComando: $cmd");
        }
        $queriesExecuted++;
    }

    // Respuesta para master_setup
    echo json_encode([
        "success" => true,
        "queries_executed" => $queriesExecuted,
        "message" => "Esquema de snapshot corregido satisfactoriamente (Fase 14)."
    ]);

} catch (Exception $e) {
    if (isset($conn) && $conn->connect_errno == 0 && $conn->in_transaction) {
        $conn->rollback();
    }
    header('HTTP/1.1 500 Internal Server Error');
    echo json_encode([
        "success" => false,
        "error" => $e->getMessage()
    ]);
}
?>
