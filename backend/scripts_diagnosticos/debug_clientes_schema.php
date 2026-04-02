<?php
require_once 'conexion.php';
$res = $conn->query("DESCRIBE clientes");
$fields = [];
while ($row = $res->fetch_assoc()) {
    $fields[] = $row['Field'];
}
echo json_encode($fields);
