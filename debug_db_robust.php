<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$servername = "localhost";
$username = "u342171239_Test";
$password = "Test_2025/-*";
$database = "u342171239_InfoApp_Test";

try {
    $conn = new mysqli($servername, $username, $password, $database);
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }
    $conn->set_charset("utf8mb4");

    echo "=== ESTADOS PROCESO ===\n";
    $res = $conn->query("SELECT id, nombre_estado, modulo FROM estados_proceso");
    while ($row = $res->fetch_assoc()) {
        echo "ID: $row[id] | Nombre: [$row[nombre_estado]] | Modulo: $row[modulo]\n";
    }

    echo "\n=== TRANSICIONES ESTADO ===\n";
    $res = $conn->query("SELECT t.*, e1.nombre_estado as ori, e2.nombre_estado as des 
                        FROM transiciones_estado t 
                        JOIN estados_proceso e1 ON t.estado_origen_id = e1.id 
                        JOIN estados_proceso e2 ON t.estado_destino_id = e2.id");
    while ($row = $res->fetch_assoc()) {
        echo "ID: $row[id] | [$row[ori]] (ID: $row[estado_origen_id]) -> [$row[des]] (ID: $row[estado_destino_id]) | Modulo: $row[modulo]\n";
    }

    echo "\n=== SERVICIO EN CUESTION ===\n";
    $res = $conn->query("SELECT id, estado FROM servicios LIMIT 5");
    while ($row = $res->fetch_assoc()) {
        echo "Servicio ID: $row[id] | Estado Actual ID: $row[estado]\n";
    }

} catch (Exception $e) {
    echo "ERROR: " . $e->getMessage();
}
?>