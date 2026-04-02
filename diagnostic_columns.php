<?php
header('Content-Type: text/plain');
require 'backend/conexion.php';

$tablas = ['servicios', 'equipo', 'inspecciones_cabecera'];

foreach ($tablas as $t) {
    echo "Tabla: $t\n";
    $res = $conn->query("SHOW COLUMNS FROM $t LIKE 'estado_id'");
    if ($res && $res->num_rows > 0) {
        echo "  - Columna 'estado_id' EXISTE.\n";
    } else {
        echo "  - Columna 'estado_id' NO EXISTE o error.\n";
    }
}

$conn->close();
?>