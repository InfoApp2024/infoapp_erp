<?php
require 'conexion.php';
$res = $conn->query('SHOW TRIGGERS');
if (!$res) {
    die($conn->error);
}
while ($row = $res->fetch_assoc()) {
    echo json_encode($row) . "\n";
}
?>