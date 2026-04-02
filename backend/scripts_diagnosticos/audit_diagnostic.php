<?php
require_once 'conexion.php';

$tables = ['servicios', 'clientes', 'inventory_items', 'inventory_movements', 'funcionario', 'usuarios'];

echo "=== DATABASE DDL ===\n\n";
foreach ($tables as $table) {
    echo "--- TABLE: $table ---\n";
    $result = $conn->query("SHOW CREATE TABLE $table");
    if ($result) {
        $row = $result->fetch_row();
        echo $row[1] . "\n\n";
    } else {
        echo "Error or Table not found: $table\n\n";
    }
}

echo "=== TRANSACTION SAMPLES ===\n";
// Diagnostic check for common patterns in specific files
$files = ['servicio/crear_servicio.php', 'inventory/movements/create_movement.php'];
foreach ($files as $file) {
    echo "--- FILE: $file ---\n";
    if (file_exists($file)) {
        $content = file_get_contents($file);
        if (strpos($content, 'autocommit(false)') !== false || strpos($content, 'START TRANSACTION') !== false) {
            echo "Transaction usage FOUND\n";
        } else {
            echo "Transaction usage NOT FOUND (explicit)\n";
        }
    } else {
        echo "File not found: $file\n";
    }
}
?>
