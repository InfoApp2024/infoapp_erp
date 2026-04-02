<?php
// backend/servicio/migracion_tipos_campos.php
// Script para asegurar que las columnas tipo_mantenimiento y centro_costo sean VARCHAR

require_once '../conexion.php';

echo "<h1>Migración de Tipos de Datos - Tabla Servicios</h1>";

try {
    // 1. Verificar estructura actual
    echo "<h3>Estructura actual:</h3>";
    $result = $conn->query("DESCRIBE servicios");
    while ($row = $result->fetch_assoc()) {
        if ($row['Field'] == 'tipo_mantenimiento' || $row['Field'] == 'centro_costo') {
            echo "Columna: <b>{$row['Field']}</b> - Tipo: <b>{$row['Type']}</b><br>";
        }
    }

    // 2. Aplicar cambios
    echo "<h3>Aplicando cambios:</h3>";

    // Tipo de Mantenimiento
    echo "Actualizando tipo_mantenimiento a VARCHAR(50)... ";
    if ($conn->query("ALTER TABLE servicios MODIFY COLUMN tipo_mantenimiento VARCHAR(50) DEFAULT NULL")) {
        echo "<span style='color:green'>EXITO</span><br>";
    } else {
        echo "<span style='color:red'>ERROR: " . $conn->error . "</span><br>";
    }

    // Centro de Costo
    echo "Actualizando centro_costo a VARCHAR(100)... ";
    if ($conn->query("ALTER TABLE servicios MODIFY COLUMN centro_costo VARCHAR(100) DEFAULT NULL")) {
        echo "<span style='color:green'>EXITO</span><br>";
    } else {
        echo "<span style='color:red'>ERROR: " . $conn->error . "</span><br>";
    }

    echo "<h3>Estructura final:</h3>";
    $result = $conn->query("DESCRIBE servicios");
    while ($row = $result->fetch_assoc()) {
        if ($row['Field'] == 'tipo_mantenimiento' || $row['Field'] == 'centro_costo') {
            echo "Columna: <b>{$row['Field']}</b> - Tipo: <b>{$row['Type']}</b><br>";
        }
    }

    echo "<br><b style='color:blue'>Migración finalizada.</b>";

} catch (Exception $e) {
    echo "<b style='color:red'>EXCEPCIÓN: " . $e->getMessage() . "</b>";
} finally {
    $conn->close();
}
?>