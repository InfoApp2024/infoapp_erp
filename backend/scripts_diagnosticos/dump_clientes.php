<?php
require 'conexion.php';
$res = $conn->query("DESCRIBE clientes");
while ($row = $res->fetch_assoc()) {
    echo $row['Field'] . " - " . $row['Type'] . "\n";
}
?>