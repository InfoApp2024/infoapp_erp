<?php
/**
 * final_workflow_fix.php
 * Script de reparación definitiva para forzar PRIMARY KEY y AUTO_INCREMENT.
 */

require_once __DIR__ . '/../../conexion.php';

echo "<html><body style='font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px;'>";
echo "<h2>--- Reparación Forzada de Llaves y Auto-incremento ---</h2>";
echo "<pre style='background: #252526; padding: 15px; border-radius: 5px; border: 1px solid #3e3e42;'>";

function applyFix($conn, $table)
{
    echo "Reparando tabla: $table...\n";

    // 1. Intentar agregar PRIMARY KEY si no la tiene
    echo "   - Asegurando PRIMARY KEY en 'id'...\n";
    try {
        $conn->query("ALTER TABLE $table ADD PRIMARY KEY (id)");
    } catch (Exception $e) {
        echo "     (Nota: " . $e->getMessage() . ")\n";
    }

    // 2. Intentar poner AUTO_INCREMENT
    echo "   - Asegurando AUTO_INCREMENT en 'id'...\n";
    try {
        $conn->query("ALTER TABLE $table MODIFY id INT AUTO_INCREMENT");
        echo "     ✅ Exito.\n";
    } catch (Exception $e) {
        echo "     ❌ Error: " . $e->getMessage() . "\n";
    }
    echo "\n";
}

try {
    // Reparar tablas principales
    applyFix($conn, 'estados_proceso');
    applyFix($conn, 'transiciones_estado');

    // Opcional: Reparar estados_base por si acaso
    applyFix($conn, 'estados_base');

    echo "✅ Reparación de estructura finalizada.\n";

} catch (Exception $e) {
    echo "❌ ERROR GENERAL: " . $e->getMessage() . "\n";
}

echo "</pre>";
echo "</body></html>";
?>