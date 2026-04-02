<?php
require_once __DIR__ . '/conexion.php';

function describe_table($conn, $table)
{
    echo "--- $table ---\n";
    $result = $conn->query("DESCRIBE `$table`");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "{$row['Field']} - {$row['Type']}\n";
        }
    } else {
        echo "Error: " . $conn->error . "\n";
    }
}

describe_table($conn, 'firmas');
describe_table($conn, 'usuarios');
describe_table($conn, 'staff');

$conn->close();
