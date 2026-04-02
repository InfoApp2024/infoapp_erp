<?php
require 'backend/conexion.php';

echo "=== ESTADOS PROCESO ===\n";
$res = $conn->query("SELECT id, nombre_estado, modulo FROM estados_proceso");
while ($row = $res->fetch_assoc()) {
    echo "ID: $row[id] | Nombre: $row[nombre_estado] | Modulo: $row[modulo]\n";
}

echo "\n=== TRANSICIONES ESTADO ===\n";
$res = $conn->query("SELECT t.*, e1.nombre_estado as ori, e2.nombre_estado as des 
                    FROM transiciones_estado t 
                    JOIN estados_proceso e1 ON t.estado_origen_id = e1.id 
                    JOIN estados_proceso e2 ON t.estado_destino_id = e2.id");
while ($row = $res->fetch_assoc()) {
    echo "ID: $row[id] | $row[ori] (ID: $row[estado_origen_id]) -> $row[des] (ID: $row[estado_destino_id]) | Modulo: $row[modulo]\n";
}
?>