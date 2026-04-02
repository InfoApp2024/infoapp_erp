<?php
// backend/inspect_schema_migration.php
require dirname(__FILE__) . '/conexion.php';

header('Content-Type: text/plain');

$tables = ['operaciones', 'servicio_staff', 'servicio_repuestos', 'servicios'];

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
}
?>