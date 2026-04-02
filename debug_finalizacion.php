<?php
require 'backend/conexion.php';

echo "--- Estados en estados_proceso for 'inspecciones' ---\n";
$sql = "SELECT id, nombre_estado, modulo FROM estados_proceso WHERE modulo = 'inspecciones'";
$res = $conn->query($sql);
if ($res) {
    while ($row = $res->fetch_assoc()) {
        print_r($row);
    }
} else {
    echo "Error query estados_proceso: " . $conn->error . "\n";
}

echo "\n--- Estados en 'estados' table (if exists) ---\n";
$sql2 = "SELECT id, nombre FROM estados";
$res2 = $conn->query($sql2);
if ($res2) {
    while ($row = $res2->fetch_assoc()) {
        print_r($row);
    }
} else {
    echo "Error query estados: " . $conn->error . "\n";
}

echo "\n--- Count pending for last inspection (debug logic) ---\n";
$sql3 = "SELECT id FROM inspecciones ORDER BY id DESC LIMIT 1";
$res3 = $conn->query($sql3);
if ($res3 && $row3 = $res3->fetch_assoc()) {
    $inspeccion_id = $row3['id'];
    echo "Checking Inspection ID: $inspeccion_id\n";

    $sql_count = "SELECT COUNT(*) as pendientes 
                  FROM inspecciones_actividades 
                  WHERE inspeccion_id = $inspeccion_id AND deleted_at IS NULL AND autorizada = 0";
    $res_count = $conn->query($sql_count);
    $row_count = $res_count->fetch_assoc();
    echo "Pendientes count: " . $row_count['pendientes'] . "\n";

    $sql_acts = "SELECT id, autorizada, deleted_at FROM inspecciones_actividades WHERE inspeccion_id = $inspeccion_id";
    $res_acts = $conn->query($sql_acts);
    while ($row_act = $res_acts->fetch_assoc()) {
        print_r($row_act);
    }
}
?>