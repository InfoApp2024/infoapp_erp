<?php
require 'conexion.php';
$res = $conn->query("SELECT * FROM fin_puc WHERE codigo_cuenta LIKE '41%'");
$rows = [];
while ($row = $res->fetch_assoc())
    $rows[] = $row;
echo json_encode($rows, JSON_PRETTY_PRINT);
?>