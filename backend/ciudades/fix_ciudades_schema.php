<?php
/**
 * fix_ciudades_schema.php
 * script para corregir el error: Field 'id' doesn't have a default value
 * en la tabla ciudades.
 */

require_once __DIR__ . '/../conexion.php';

echo "--- Iniciando reparación de la tabla 'ciudades' ---\n";

try {
    // 1. Verificar estructura actual
    $result = $conn->query("DESCRIBE ciudades");
    $has_auto_increment = false;

    if ($result) {
        while ($row = $result->fetch_assoc()) {
            if ($row['Field'] === 'id' && strpos(strtolower($row['Extra']), 'auto_increment') !== false) {
                $has_auto_increment = true;
                break;
            }
        }
    }

    if ($has_auto_increment) {
        echo "✅ La tabla 'ciudades' ya tiene AUTO_INCREMENT en la columna 'id'.\n";
    } else {
        echo "🔧 Reparando llaves y AUTO_INCREMENT...\n";

        // Intentar añadir Primary Key primero (por si se perdió en la importación)
        // Usamos un try-catch silencioso para la PK por si ya existe pero no es AI
        @$conn->query("ALTER TABLE ciudades ADD PRIMARY KEY (id)");

        $sql = "ALTER TABLE ciudades MODIFY id INT AUTO_INCREMENT";

        if ($conn->query($sql)) {
            echo "✅ ¡Éxito! AUTO_INCREMENT y Llave Primaria configurados correctamente.\n";
        } else {
            throw new Exception("Error al ejecutar ALTER TABLE: " . $conn->error);
        }
    }

} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
    echo "\nSugerencia: Intenta ejecutar el siguiente SQL manualmente en tu gestor de base de datos (phpMyAdmin, etc.):\n";
    echo "ALTER TABLE ciudades MODIFY id INT AUTO_INCREMENT;\n";
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>