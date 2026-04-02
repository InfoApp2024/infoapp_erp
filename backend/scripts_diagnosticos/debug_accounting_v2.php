<?php
require 'conexion.php';

function inspectTable($conn, $table)
{
    echo "--- TABLE: $table ---\n";
    $res = $conn->query("DESCRIBE $table");
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            echo $row['Field'] . " | " . $row['Type'] . "\n";
        }
    } else {
        echo "Error: " . $conn->error . "\n";
    }
    echo "\n";
}

inspectTable($conn, 'impuestos_config');
inspectTable($conn, 'cnf_tarifas_ica');
inspectTable($conn, 'fin_config_causacion');
inspectTable($conn, 'fin_puc');

echo "--- CAUSACION RULES ---\n";
$res = $conn->query("SELECT c.*, p.codigo_cuenta FROM fin_config_causacion c JOIN fin_puc p ON c.puc_cuenta_id = p.id WHERE c.evento_codigo = 'GENERAR_FACTURA'");
while ($row = $res->fetch_assoc()) {
    echo "Rule: " . $row['descripcion'] . " | Base: " . $row['base_calculo'] . " | Pct: " . $row['porcentaje'] . " | Account: " . $row['codigo_cuenta'] . "\n";
}
?>