<?php
require 'backend/conexion.php';

$output = "--- DIAGNOSTICO DE ESTADOS ---\n";

$sql = "SELECT id, nombre_estado, modulo FROM estados_proceso";
$res = $conn->query($sql);
if ($res) {
    while ($row = $res->fetch_assoc()) {
        $output .= "ID: {$row['id']} | Nombre: {$row['nombre_estado']} | Modulo: {$row['modulo']}\n";
    }
} else {
    $output .= "Error query estados_proceso: " . $conn->error . "\n";
}

$output .= "\n--- TABLA ESTADOS (legacy?) ---\n";
$sql2 = "SELECT id, nombre, modulo_id FROM estados";
$res2 = $conn->query($sql2);
if ($res2) {
    while ($row = $res2->fetch_assoc()) {
        $output .= "ID: {$row['id']} | Nombre: {$row['nombre']} | ModuloID: {$row['modulo_id']}\n";
    }
} else {
    $output .= "Error query estados: " . $conn->error . "\n";
}

file_put_contents('dump_estados.txt', $output);
echo "Dumped to dump_estados.txt\n";
?>