<?php
require 'conexion.php';
$res = $conn->query("SELECT * FROM impuestos_config");
if ($res) {
    while ($row = $res->fetch_assoc()) {
        echo "ID: " . $row['id'] . " | Tipo: " . $row['tipo_impuesto'] . " | Porcentaje: " . $row['porcentaje'] . " | CIIU: " . $row['codigo_ciiu'] . " | Base Pesos: " . $row['base_minima_pesos'] . "\n";
    }
} else {
    echo "Error: " . $conn->error;
}
?>