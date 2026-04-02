<?php
// backend/migrations/v7_add_actividad_to_operaciones.php
require_once dirname(__FILE__) . '/../conexion.php';

try {
    // 1. Agregar columna actividad_estandar_id
    $checkColumn = "SHOW COLUMNS FROM `operaciones` LIKE 'actividad_estandar_id'";
    $result = $conn->query($checkColumn);

    if ($result->num_rows == 0) {
        echo "Agregando columna actividad_estandar_id a la tabla operaciones...\n";
        $sql = "ALTER TABLE `operaciones` 
                ADD COLUMN `actividad_estandar_id` INT NULL AFTER `servicio_id`,
                ADD CONSTRAINT `fk_operaciones_actividad` 
                FOREIGN KEY (`actividad_estandar_id`) REFERENCES `actividades_estandar`(`id`) ON DELETE SET NULL";

        if ($conn->query($sql)) {
            echo "✅ Columna actividad_estandar_id agregada exitosamente.\n";
        } else {
            throw new Exception("Error al agregar columna: " . $conn->error);
        }
    } else {
        echo "ℹ️ La columna actividad_estandar_id ya existe.\n";
    }

} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
}
?>