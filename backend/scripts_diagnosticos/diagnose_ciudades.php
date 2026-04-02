<?php
require 'conexion.php';

echo "--- TABLE: ciudades ---\n";
$result = $conn->query("DESCRIBE ciudades");
if ($result) {
    while ($row = $result->fetch_assoc()) {
        echo "{$row['Field']} | {$row['Type']} | {$row['Null']} | {$row['Key']} | {$row['Default']} | {$row['Extra']}\n";
    }
} else {
    echo "Error: " . $conn->error . "\n";
}

$pk_check = $conn->query("SHOW CREATE TABLE ciudades");
if ($pk_check) {
    echo "\n--- CREATE TABLE Statement ---\n";
    $row = $pk_check->fetch_assoc();
    echo $row['Create Table'] . "\n";
}
?>