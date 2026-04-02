<?php
// fix_existing_statuses.php
require 'conexion.php';

// Disable strict mode for cleaning
$conn->query("SET SESSION sql_mode = ''");

echo "--- REPARANDO ESTADOS INVALIDOS ---\n";

// Servicios que tengan estados raros o NO_FACTURADO los pasamos a PENDIENTE
$sql = "UPDATE fac_control_servicios 
        SET estado_comercial_cache = 'PENDIENTE' 
        WHERE estado_comercial_cache NOT IN ('PENDIENTE', 'CAUSADO', 'FACTURADO', 'ANULADO') 
           OR estado_comercial_cache = '' 
           OR estado_comercial_cache IS NULL";

if ($conn->query($sql)) {
    echo "✅ " . $conn->affected_rows . " registros actualizados a PENDIENTE.\n";
} else {
    echo "❌ Error: " . $conn->error . "\n";
}

$conn->close();
