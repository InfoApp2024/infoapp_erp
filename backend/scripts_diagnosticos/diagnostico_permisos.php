<?php
require 'c:/Users/ferch/Documents/infoapp_proyecto/backend/conexion.php';

$users = [47, 21];

foreach ($users as $userId) {
    echo "--- Permisos para Usuario ID: $userId ---\n";
    $sql = "SELECT module, action, allowed FROM user_permissions WHERE user_id = $userId";
    $result = $conn->query($sql);

    if ($result->num_rows > 0) {
        $modules = [];
        while ($row = $result->fetch_assoc()) {
            $modules[$row['module']][] = $row['action'];
        }
        foreach ($modules as $mod => $actions) {
            echo "Módulo [$mod]: " . implode(", ", $actions) . "\n";
        }
    } else {
        echo "No se encontraron permisos en la tabla 'user_permissions'.\n";
    }
    echo "\n";
}

$conn->close();
?>