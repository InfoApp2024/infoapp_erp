<?php
require_once __DIR__ . '/conexion.php';

try {
    // Verificar si la columna ya existe
    $check = $conn->query("SHOW COLUMNS FROM notas LIKE 'es_automatica'");
    if ($check->num_rows == 0) {
        $sql = "ALTER TABLE notas ADD COLUMN es_automatica TINYINT(1) DEFAULT 0 AFTER usuario_id";
        if ($conn->query($sql)) {
            echo "Columna 'es_automatica' añadida con éxito.\n";
        } else {
            echo "Error: " . $conn->error . "\n";
        }
    } else {
        echo "La columna 'es_automatica' ya existe.\n";
    }
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
} finally {
    $conn->close();
}
?>