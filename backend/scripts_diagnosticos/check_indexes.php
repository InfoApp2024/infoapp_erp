<?php
require_once 'conexion.php';

header('Content-Type: application/json');

$tables = ['notas', 'firmas', 'servicios_desbloqueos_repuestos', 'servicios'];
$results = [];

foreach ($tables as $table) {
    try {
        $result = $conn->query("SHOW INDEX FROM $table");
        $indexes = [];
        while ($row = $result->fetch_assoc()) {
            $indexes[] = $row;
        }
        $results[$table] = $indexes;
    } catch (Exception $e) {
        $results[$table] = "Error: " . $e->getMessage();
    }
}

echo json_encode($results, JSON_PRETTY_PRINT);
