<?php
include 'conexion.php';
$res = $conn->query("DESCUBE usuarios"); // Wait, it should be DESCRIBE
$res = $conn->query("DESCRIBE usuarios");
if ($res) {
    while ($row = $res->fetch_assoc()) {
        echo $row['Field'] . "\n";
    }
} else {
    echo "Error: " . $conn->error;
}
$conn->close();
