<?php
require 'conexion.php';
$sql = "ALTER TABLE inspecciones_actividades ADD COLUMN deleted_by INT NULL AFTER deleted_at";
if ($conn->query($sql)) {
    echo "Columna 'deleted_by' añadida exitosamente.";
} else {
    // Si ya existe, nos dará error, lo comprobamos
    if ($conn->errno == 1060) {
        echo "La columna 'deleted_by' ya existe.";
    } else {
        echo "Error: " . $conn->error;
    }
}
?>