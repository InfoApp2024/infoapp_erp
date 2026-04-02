<?php
// debug_fac_control.php
require 'conexion.php';

echo "--- DEFINICION ACTUAL ---\n";
$r = $conn->query("SHOW CREATE TABLE fac_control_servicios");
$row = $r->fetch_assoc();
echo $row['Create Table'] . "\n\n";

echo "--- VALORES ACTUALES EN CACHE ---\n";
$r2 = $conn->query("SELECT estado_comercial_cache, COUNT(*) as total FROM fac_control_servicios GROUP BY estado_comercial_cache");
while ($row = $r2->fetch_assoc()) {
    echo "[" . ($row['estado_comercial_cache'] ?? 'NULL') . "] -> " . $row['total'] . "\n";
}

$conn->close();
