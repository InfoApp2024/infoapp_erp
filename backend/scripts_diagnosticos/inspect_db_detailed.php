<?php
require 'conexion.php';
// $conn is already established in conexion.php

$tables = ['servicio_staff', 'servicio_repuestos', 'operaciones'];

foreach ($tables as $table) {
    echo "\n--- TABLE: $table ---\n";
    $result = $conn->query("DESCRIBE `$table` ");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "{$row['Field']} - {$row['Type']} - {$row['Null']} - {$row['Key']} - {$row['Extra']}\n";
        }
    } else {
        echo "Error DESCRIBE: " . $conn->error . "\n";
    }

    echo "\n--- INDEXES: $table ---\n";
    $result = $conn->query("SHOW INDEX FROM `$table` ");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "{$row['Key_name']} - {$row['Column_name']} - Non_unique: {$row['Non_unique']}\n";
        }
    } else {
        echo "Error INDEXES: " . $conn->error . "\n";
    }
}
$conn->close();
