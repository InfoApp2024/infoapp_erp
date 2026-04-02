<?php
include 'conexion.php';
$res = $conn->query("DESCRIBE ciudades");
if ($res) {
    while ($row = $res->fetch_assoc()) {
        echo $row['Field'] . "\n";
    }
}
$conn->close();
