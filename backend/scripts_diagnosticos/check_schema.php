<?php
require 'conexion.php';
echo "--- impuestos_config ---\n";
$res = $conn->query("DESCRIBE impuestos_config");
while ($row = $res->fetch_assoc()) {
    echo $row['Field'] . " - " . $row['Type'] . "\n";
}

echo "\n--- cnf_tarifas_ica ---\n";
$res = $conn->query("DESCRIBE cnf_tarifas_ica");
while ($row = $res->fetch_assoc()) {
    echo $row['Field'] . " - " . $row['Type'] . "\n";
}
?>