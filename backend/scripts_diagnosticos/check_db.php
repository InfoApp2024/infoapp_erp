<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
require 'conexion.php';
if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}
$res = $conn->query("DESCRIBE funcionario");
if (!$res) {
    die("Query failed: " . $conn->error);
}
$columns = [];
while ($row = $res->fetch_assoc()) {
    $columns[] = $row;
}
echo json_encode($columns);
?>