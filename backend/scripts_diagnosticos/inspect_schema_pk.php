<?php
// backend/inspect_schema_pk.php
require dirname(__FILE__) . '/conexion.php';

header('Content-Type: text/plain');

$tables = ['servicios', 'usuarios', 'actividades_estandar'];

foreach ($tables as $table) {
    echo "=== TABLA: $table ===\n";

    // Check if table exists
    $check = $conn->query("SHOW TABLES LIKE '$table'");
    if ($check->num_rows == 0) {
        echo "❌ NO EXISTE\n\n";
        continue;
    }

    // Get Create Table statement
    $result = $conn->query("SHOW CREATE TABLE $table");
    if ($result) {
        $row = $result->fetch_row();
        echo $row[1] . "\n\n";
    } else {
        echo "Error: " . $conn->error . "\n\n";
    }

    // Check ID column details specifically
    $result = $conn->query("SHOW COLUMNS FROM $table LIKE 'id'");
    if ($result) {
        $row = $result->fetch_assoc();
        echo "ID details: " . print_r($row, true) . "\n";
    }
    echo "\n";
}
?>