<?php
// run_fix_estado.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require 'conexion.php';

// Disable strict mode for this session to allow cleaning "corrupted" enum values
$conn->query("SET SESSION sql_mode = ''");

// 1. Limpiar datos inválidos (si hay valores truncados o nulos)
$conn->query("UPDATE fac_control_servicios SET estado_comercial_cache = 'PENDIENTE' WHERE estado_comercial_cache NOT IN ('PENDIENTE', 'FACTURADO', 'ANULADO') OR estado_comercial_cache IS NULL");

// 2. Aplicar el ALTER TABLE con los nuevos valores
$sql = "ALTER TABLE fac_control_servicios 
        MODIFY COLUMN estado_comercial_cache ENUM('PENDIENTE', 'CAUSADO', 'FACTURADO', 'ANULADO') DEFAULT 'PENDIENTE'";

if ($conn->query($sql)) {
    echo "✅ Columna estado_comercial_cache actualizada exitosamente (Strict Mode bypass).";
} else {
    echo "❌ Error: " . $conn->error;
}

$conn->close();
