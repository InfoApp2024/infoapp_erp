<?php
// migration_v5_add_modulo_to_plantillas.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Intentar cargar conexión desde varias ubicaciones posibles
if (file_exists(__DIR__ . '/../conexion.php')) {
    require_once __DIR__ . '/../conexion.php';
} else if (file_exists(__DIR__ . '/conexion.php')) {
    require_once __DIR__ . '/conexion.php';
} else {
    die("❌ ERROR: No se pudo encontrar 'conexion.php'. Verifica la ubicación del script.");
}

try {
    echo "Iniciando migración...\n";

    // 1. Verificar si la columna ya existe
    $check_column = $conn->query("SHOW COLUMNS FROM plantillas LIKE 'modulo'");

    if ($check_column->num_rows == 0) {
        echo "Añadiendo columna 'modulo' a la tabla 'plantillas'...\n";

        $sql = "ALTER TABLE plantillas 
                ADD COLUMN modulo VARCHAR(50) DEFAULT 'servicios' AFTER nombre";

        if ($conn->query($sql) === TRUE) {
            echo "✅ Columna 'modulo' añadida exitosamente.\n";

            // 2. Asegurar que los existentes tengan 'servicios' (aunque ya tiene DEFAULT)
            $conn->query("UPDATE plantillas SET modulo = 'servicios' WHERE modulo IS NULL OR modulo = ''");
            echo "✅ Registros existentes actualizados a 'servicios'.\n";
        } else {
            throw new Exception("Error al añadir columna: " . $conn->error);
        }
    } else {
        echo "ℹ️ La columna 'modulo' ya existe.\n";
    }

    echo "Migración completada con éxito.\n";

} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
}
?>