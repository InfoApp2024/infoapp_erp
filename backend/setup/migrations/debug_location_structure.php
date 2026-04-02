<?php
/**
 * debug_location_structure.php
 * Script de diagnóstico para las tablas de ubicación.
 */

require_once __DIR__ . '/../../conexion.php';

echo "<html><body style='font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px;'>";
echo "<h2>--- Diagnóstico de Estructura de Ubicaciones ---</h2>";
echo "<pre style='background: #252526; padding: 15px; border-radius: 5px; border: 1px solid #3e3e42;'>";

function inspectTable($conn, $tableName)
{
    echo "<h3>Inspecionando tabla: $tableName</h3>";
    $result = $conn->query("SHOW TABLES LIKE '$tableName'");
    if ($result->num_rows == 0) {
        echo "<span style='color: #f44336;'>❌ La tabla '$tableName' NO existe.</span>\n";
        return;
    }
    echo "<span style='color: #4caf50;'>✅ La tabla '$tableName' existe.</span>\n";

    echo "\n<b>Columnas:</b>\n";
    $columns = $conn->query("DESCRIBE $tableName");
    while ($col = $columns->fetch_assoc()) {
        printf(
            "   - %-20s | %-15s | %-4s | %-4s | %s\n",
            $col['Field'],
            $col['Type'],
            $col['Null'],
            $col['Key'],
            $col['Default']
        );
    }

    echo "\n<b>Registros (primeros 5):</b>\n";
    $data = $conn->query("SELECT * FROM $tableName LIMIT 5");
    if ($data->num_rows == 0) {
        echo "   (Tabla vacía)\n";
    } else {
        while ($row = $data->fetch_assoc()) {
            print_r($row);
        }
    }
    echo "<hr style='border: 0; border-top: 1px dashed #555; margin: 20px 0;'>";
}

try {
    inspectTable($conn, 'departamentos');
    inspectTable($conn, 'ciudades');
} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
}

echo "</pre>";
echo "</body></html>";
?>