<?php
require '../../conexion.php';
$result = $conn->query("DESCRIBE user_permissions");
$structure = [];
while ($row = $result->fetch_assoc()) {
    $structure[] = $row;
}
echo json_encode($structure, JSON_PRETTY_PRINT);
?>