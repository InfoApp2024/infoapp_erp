<?php
require 'backend/conexion.php';
$stmt = $conn->prepare('SELECT id, nombre_estado, color FROM estados_proceso WHERE modulo = ? ORDER BY id ASC');
$modulo = 'inspecciones';
$stmt->bind_param('s', $modulo);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    echo "ID: " . $row['id'] . " - Nombre: " . $row['nombre_estado'] . "\n";
}
?>