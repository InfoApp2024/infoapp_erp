<?php
require 'conexion.php';
$res = $conn->query("SELECT * FROM impuestos_config");
while ($row = $res->fetch_assoc()) {
    echo json_encode($row) . "\n";
}
?>