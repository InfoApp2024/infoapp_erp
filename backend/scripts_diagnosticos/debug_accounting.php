<?php
require 'conexion.php';

function dumpTable($conn, $tableName)
{
    echo "--- TABLE: $tableName ---\n";
    $res = $conn->query("DESCRIBE $tableName");
    if (!$res) {
        echo "Error describing $tableName: " . $conn->error . "\n";
        return;
    }
    while ($row = $res->fetch_assoc()) {
        echo $row['Field'] . " (" . $row['Type'] . ")\n";
    }

    echo "\n--- DATA (up to 20 rows): $tableName ---\n";
    $res = $conn->query("SELECT * FROM $tableName LIMIT 20");
    while ($row = $res->fetch_assoc()) {
        echo json_encode($row) . "\n";
    }
    echo "\n";
}

dumpTable($conn, 'impuestos_config');
dumpTable($conn, 'fin_config_causacion');
dumpTable($conn, 'cnf_tarifas_ica');
?>