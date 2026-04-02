<?php
// backend/staff/update_staff_db.php
// Script para actualizar la estructura de la tabla 'staff' y agregar 'id_especialidad'

error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../conexion.php';

echo "<h2>Actualización de Estructura - Tabla Staff</h2>";

// 1. Verificar si la columna id_especialidad existe en staff
$colCheck = $conn->query("SHOW COLUMNS FROM staff LIKE 'id_especialidad'");

if ($colCheck->num_rows == 0) {
    echo "Agregando columna id_especialidad a tabla staff...<br>";
    
    // Agregar columna
    // Asumimos que la tabla 'especialidades' tiene id INT.
    // Usamos NULL por defecto.
    $sql = "ALTER TABLE staff ADD COLUMN id_especialidad INT NULL AFTER position_id";
    
    if ($conn->query($sql)) {
        echo "✅ Columna id_especialidad agregada correctamente.<br>";
        
        // Agregar Foreign Key
        // Verificamos primero si existe la tabla especialidades
        $tableCheck = $conn->query("SHOW TABLES LIKE 'especialidades'");
        if ($tableCheck->num_rows > 0) {
            $sqlFK = "ALTER TABLE staff ADD CONSTRAINT fk_staff_especialidad 
                      FOREIGN KEY (id_especialidad) REFERENCES especialidades(id) 
                      ON DELETE SET NULL";
            
            if ($conn->query($sqlFK)) {
                echo "✅ Foreign Key fk_staff_especialidad creada correctamente.<br>";
            } else {
                echo "⚠️ Error creando Foreign Key: " . $conn->error . "<br>";
            }
        } else {
            echo "⚠️ Tabla 'especialidades' no encontrada. No se creó FK.<br>";
        }
        
    } else {
        echo "❌ Error agregando columna: " . $conn->error . "<br>";
    }
} else {
    echo "ℹ️ La columna id_especialidad ya existe en la tabla staff.<br>";
}

echo "<br><strong>Proceso finalizado.</strong>";
?>
