<?php
require 'conexion.php';

$sqlFile = 'migrations/accounting_phase_4_consecutivos.sql';
if (!file_exists($sqlFile)) {
    die("Archivo no encontrado: $sqlFile\n");
}

$sql = file_get_contents($sqlFile);

if ($conn->multi_query($sql)) {
    do {
        if ($res = $conn->store_result()) {
            $res->free();
        }
    } while ($conn->next_result());
    echo "MIGRACION EXITOSA\n";
} else {
    echo "ERROR EN MIGRACION: " . $conn->error . "\n";
}
