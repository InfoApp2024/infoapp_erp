<?php
require 'conexion.php';

$sql = file_get_contents('migrations/accounting_phase_2_expansion.sql');

// Split the SQL into individual statements
$statements = explode(';', $sql);

$conn->begin_transaction();
try {
    foreach ($statements as $stmt) {
        $stmt = trim($stmt);
        if (empty($stmt))
            continue;

        if (!$conn->query($stmt)) {
            throw new Exception("Error en SQL: " . $conn->error . "\nSentencia: " . $stmt);
        }
    }
    $conn->commit();
    echo "✅ Migración de Expansión (M.O.) aplicada exitosamente.";
} catch (Exception $e) {
    $conn->rollback();
    echo "❌ Error al aplicar migración: " . $e->getMessage();
}
?>