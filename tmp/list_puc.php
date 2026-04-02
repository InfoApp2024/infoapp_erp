<?php
require 'backend/conexion.php';
$res = $conn->query("SELECT id, codigo_cuenta, nombre FROM fin_puc WHERE codigo_cuenta LIKE '1355%' OR nombre LIKE '%RETE%' OR nombre LIKE '%ICA%' LIMIT 100");
if ($res) {
    echo "ID | CODIGO | NOMBRE\n";
    echo "--------------------\n";
    while ($r = $res->fetch_assoc()) {
        echo "{$r['id']} | {$r['codigo_cuenta']} | {$r['nombre']}\n";
    }
} else {
    echo "Error querying fin_puc: " . $conn->error;
}
