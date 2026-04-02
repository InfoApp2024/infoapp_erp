<?php
require 'conexion.php';

$sql = "ALTER TABLE usuarios ADD COLUMN funcionario_id INT NULL AFTER id";
if ($conn->query($sql)) {
    echo "Columna funcionario_id agregada correctamente.\n";
} else {
    echo "Error agregando columna: " . $conn->error . "\n";
}

$sqlIndex = "ALTER TABLE usuarios ADD INDEX idx_funcionario (funcionario_id)";
if ($conn->query($sqlIndex)) {
    echo "Índice idx_funcionario agregado correctamente.\n";
} else {
    echo "Error agregando índice: " . $conn->error . "\n";
}

$conn->close();
?>