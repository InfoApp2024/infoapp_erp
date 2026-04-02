<?php
require 'backend/conexion.php';
$codes = ['135517', '135515', '135518'];
foreach ($codes as $c) {
    $res = $conn->query("SELECT id, nombre FROM fin_puc WHERE codigo_cuenta = '$c'");
    if ($res && $r = $res->fetch_assoc()) {
        echo "Code $c: ID=" . $r['id'] . " Name=" . $r['nombre'] . "\n";
    } else {
        echo "Code $c: NOT FOUND\n";
    }
}
