<?php
// backend/check_columns.php
require __DIR__ . '/conexion.php';
$res = $conn->query("SHOW COLUMNS FROM inventory_items");
if ($res) {
    while ($row = $res->fetch_assoc()) {
        echo $row['Field'] . "\n";
    }
} else {
    echo "Error: " . $conn->error;
}
?>