<?php
require_once __DIR__ . '/../conexion.php';

function d($conn, $table)
{
    echo "\n--- $table ---\n";
    $res = $conn->query("DESCRIBE `$table`");
    if (!$res) {
        echo "Error: " . $conn->error . "\n";
        return;
    }
    while ($row = $res->fetch_assoc())
        echo "{$row['Field']} {$row['Type']}\n";
}

d($conn, 'firmas');
d($conn, 'usuarios');
d($conn, 'staff');

$conn->close();
