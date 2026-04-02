<?php
require 'conexion.php';

try {
    $sql = "ALTER TABLE inspecciones_actividades ADD COLUMN created_by INT AFTER notas";
    if ($conn->query($sql)) {
        echo "Columna 'created_by' añadida exitosamente a 'inspecciones_actividades'.\n";

        // Opcional: Poblar con el creador de la inspección para datos existentes
        $sql_update = "UPDATE inspecciones_actividades ia 
                       JOIN inspecciones i ON ia.inspeccion_id = i.id 
                       SET ia.created_by = i.created_by 
                       WHERE ia.created_by IS NULL";
        if ($conn->query($sql_update)) {
            echo "Datos existentes actualizados con el creador de la inspección.\n";
        }
    } else {
        echo "Error añadiendo columna: " . $conn->error . "\n";
    }
} catch (Exception $e) {
    echo "Excepción: " . $e->getMessage() . "\n";
} finally {
    $conn->close();
}
?>