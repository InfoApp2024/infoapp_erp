<?php
require_once 'conexion.php';
$res = $conn->query("DESCRIBE operaciones");
$fields = [];
while ($row = $res->fetch_assoc()) {
    $fields[] = $row['Field'];
}
echo json_encode($fields);
