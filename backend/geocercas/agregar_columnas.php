<?php
// backend/geocercas/agregar_columnas.php
// ⚠️ ELIMINAR ESTE ARCHIVO DESPUÉS DE EJECUTARLO

require_once '../conexion.php';

try {
    // Verificar si las columnas ya existen
    $result = $conn->query("SHOW COLUMNS FROM registros_geocerca LIKE 'foto_ingreso'");

    if ($result->num_rows > 0) {
        echo "✅ Las columnas ya existen. No es necesario ejecutar el script.\n";
        exit;
    }

    // Agregar las columnas
    $sql = "ALTER TABLE registros_geocerca 
            ADD COLUMN foto_ingreso VARCHAR(255) NULL AFTER fecha_ingreso,
            ADD COLUMN foto_salida VARCHAR(255) NULL AFTER fecha_salida,
            ADD COLUMN fecha_captura_ingreso DATETIME NULL AFTER foto_ingreso,
            ADD COLUMN fecha_captura_salida DATETIME NULL AFTER foto_salida";

    if ($conn->query($sql) === TRUE) {
        echo "✅ Columnas agregadas exitosamente:\n";
        echo "   - foto_ingreso (VARCHAR 255)\n";
        echo "   - foto_salida (VARCHAR 255)\n";
        echo "   - fecha_captura_ingreso (DATETIME)\n";
        echo "   - fecha_captura_salida (DATETIME)\n";
        echo "\n⚠️ IMPORTANTE: Elimina este archivo por seguridad.\n";
    } else {
        echo "❌ Error al agregar columnas: " . $conn->error . "\n";
    }
} catch (Exception $e) {
    echo "❌ Error: " . $e->getMessage() . "\n";
}

$conn->close();
?>