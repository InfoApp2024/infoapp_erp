<?php
/**
 * run_migration_13.php
 * Cambia el tipo de columna de 'campo' en fac_snapshot_ajustes de ENUM a VARCHAR 
 * para permitir descripciones detalladas de los repuestos editados.
 */
require_once 'conexion.php';

try {
    echo "Iniciando migración #13...\n";

    // 1. Cambiar la tabla fac_snapshot_ajustes
    $sql = "ALTER TABLE fac_snapshot_ajustes MODIFY COLUMN campo VARCHAR(100) NOT NULL";

    if ($conn->query($sql) === TRUE) {
        echo "✅ Columna 'campo' actualizada exitosamente a VARCHAR(100).\n";
    } else {
        throw new Exception("Error al actualizar la columna: " . $conn->error);
    }

    echo "Migración completada con éxito.\n";

} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
} finally {
    if (isset($conn))
        $conn->close();
}
