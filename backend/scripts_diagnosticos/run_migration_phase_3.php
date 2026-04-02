<?php
// run_migration_phase_3.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'conexion.php';

$sql = file_get_contents('migrations/accounting_phase_3_commercial.sql');

if ($conn->multi_query($sql)) {
    do {
        if ($result = $conn->store_result()) {
            $result->free();
        }
    } while ($conn->next_result());
    echo "✅ Migración Fase 3 aplicada con éxito.\n";
} else {
    echo "❌ Error en la migración: " . $conn->error . "\n";
}

$conn->close();
