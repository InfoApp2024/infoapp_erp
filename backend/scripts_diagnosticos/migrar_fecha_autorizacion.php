<?php
require 'conexion.php';

try {
    // 1. Añadir columna si no existe
    $sql_check = "SHOW COLUMNS FROM inspecciones_actividades LIKE 'fecha_autorizacion'";
    $result = $conn->query($sql_check);

    if ($result->num_rows === 0) {
        $sql_alter = "ALTER TABLE inspecciones_actividades ADD COLUMN fecha_autorizacion DATETIME NULL AFTER autorizada";
        if ($conn->query($sql_alter)) {
            echo "Columna 'fecha_autorizacion' añadida exitosamente.\n";

            // 2. Inicializar datos para actividades ya autorizadas usando updated_at como aproximación
            $sql_init = "UPDATE inspecciones_actividades SET fecha_autorizacion = updated_at WHERE autorizada = 1 AND fecha_autorizacion IS NULL";
            $conn->query($sql_init);
            echo "Datos inicializados para actividades existentes.\n";
        } else {
            throw new Exception("Error al añadir columna: " . $conn->error);
        }
    } else {
        echo "La columna 'fecha_autorizacion' ya existe.\n";
    }

} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
} finally {
    $conn->close();
}
?>