<?php
require 'conexion.php';
$res = $conn->query("DESCRIBE servicios");
while ($row = $res->fetch_assoc()) {
    echo $row['Field'] . " - " . $row['Type'] . PHP_EOL;
}
$conn->close();
?>