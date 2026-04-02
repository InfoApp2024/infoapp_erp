<?php
require 'backend/conexion.php';
$servicio_id = 299;

echo "--- DATOS DEL SERVICIO ---\n";
$res = $conn->query("SELECT s.id, s.cliente_id, s.v_total, fcs.valor_snapshot, fcs.total_repuestos, fcs.total_mano_obra 
                     FROM servicios s 
                     LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id 
                     WHERE s.id = $servicio_id");
print_r($res->fetch_assoc());

echo "\n--- OPERACIONES Y TECNICOS ---\n";
$res = $conn->query("SELECT o.id, o.tecnico_responsable_id, o.fecha_inicio, o.fecha_fin, u.nombre, u.ID_ESPECIALIDAD 
                     FROM operaciones o 
                     LEFT JOIN usuarios u ON o.tecnico_responsable_id = u.id 
                     WHERE o.servicio_id = $servicio_id");
while ($row = $res->fetch_assoc()) {
    echo "Operación DB: " . $row['id'] . " | Técnico: " . $row['nombre'] . " | EspID: " . $row['ID_ESPECIALIDAD'] . " | Inicio: " . $row['fecha_inicio'] . " | Fin: " . $row['fecha_fin'] . "\n";

    if ($row['ID_ESPECIALIDAD']) {
        $esp_id = $row['ID_ESPECIALIDAD'];
        $tarRes = $conn->query("SELECT valor FROM cliente_perfiles WHERE cliente_id = (SELECT cliente_id FROM servicios WHERE id = $servicio_id) AND especialidad_id = $esp_id");
        $tarifa = $tarRes->fetch_assoc();
        echo "  > Tarifa Cliente: " . ($tarifa ? $tarifa['valor'] : "NO ENCONTRADA") . "\n";

        $baseRes = $conn->query("SELECT valor_hr FROM especialidades WHERE id = $esp_id");
        $base = $baseRes->fetch_assoc();
        echo "  > Tarifa Base: " . ($base ? $base['valor_hr'] : "NO ENCONTRADA") . "\n";
    }
}

echo "\n--- REPUESTOS (Detalle Unitario) ---\n";
// Asumiendo que los repuestos están en una tabla de recursos o similar vinculada a operaciones
$res = $conn->query("SELECT r.* FROM servicios_repuestos r WHERE r.servicio_id = $servicio_id");
while ($row = $res->fetch_assoc()) {
    print_r($row);
}
