<?php
// align_commercial_statuses.php
require 'conexion.php';

// Disable strict mode for migration
$conn->query("SET SESSION sql_mode = ''");

echo "--- ALINEANDO ESTADOS COMERCIALES (REQ 2.2) ---\n";

// 1. Alterar tabla para soportar los nombres exactos del requerimiento + CAUSADO (puente contable)
$sqlAlter = "ALTER TABLE fac_control_servicios 
             MODIFY COLUMN estado_comercial_cache 
             ENUM('NO_FACTURADO', 'CAUSADO', 'FACTURACION_PARCIAL', 'FACTURADO_TOTAL', 'ANULADO') 
             DEFAULT 'NO_FACTURADO'";

if ($conn->query($sqlAlter)) {
    echo "✅ Estructura de tabla alineada.\n";
} else {
    echo "❌ Error Alter: " . $conn->error . "\n";
}

// 2. Mapear estados anteriores a los nuevos
// PENDIENTE -> NO_FACTURADO
$conn->query("UPDATE fac_control_servicios SET estado_comercial_cache = 'NO_FACTURADO' WHERE estado_comercial_cache = 'PENDIENTE' OR estado_comercial_cache = '' OR estado_comercial_cache IS NULL");

echo "✅ Datos migrados a NO_FACTURADO.\n";

$conn->close();
