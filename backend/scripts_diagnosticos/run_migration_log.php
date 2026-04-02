<?php
// run_migration_log.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'conexion.php';

$sql = file_get_contents('migrations/accounting_phase_2_log.sql');

if ($conn->multi_query($sql)) {
    do {
        if ($res = $conn->store_result()) {
            $res->free();
        }
    } while ($conn->more_results() && $conn->next_result());
    echo "✅ Migración fin_asientos_log aplicada exitosamente.";
} else {
    echo "❌ Error: " . $conn->error;
}

$conn->close();
