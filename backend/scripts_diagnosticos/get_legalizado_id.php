<?php
// get_legalizado_id.php
require 'conexion.php';
$sql = "SELECT id, nombre_estado FROM estados_proceso WHERE estado_base_codigo = 'LEGALIZADO'";
$res = $conn->query($sql);
while ($row = $res->fetch_assoc()) {
    echo "ID: {$row['id']} | Nombre: {$row['nombre_estado']}\n";
}
$conn->close();
