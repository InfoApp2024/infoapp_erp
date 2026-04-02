<?php
// Script de inspección profunda para OT 1280
require 'backend/conexion.php';

$no_orden = '1280';
echo "🔍 Analizando OT #$no_orden\n";

$res = $conn->query("SELECT id, cliente_id FROM servicios WHERE numero_orden = '$no_orden'");
$servicio = $res->fetch_assoc();

if (!$servicio) {
    echo "❌ OT no encontrada en la tabla servicios.\n";
    exit;
}

$servicio_id = $servicio['id'];
$cliente_id = $servicio['cliente_id'];
echo "✅ Servicio ID: $servicio_id | Cliente ID: $cliente_id\n\n";

echo "--- OPERACIONES ---\n";
$resOps = $conn->query("SELECT o.id, o.tecnico_responsable_id, o.fecha_inicio, o.fecha_fin, u.nombre, u.ID_ESPECIALIDAD 
                        FROM operaciones o 
                        LEFT JOIN usuarios u ON o.tecnico_responsable_id = u.id 
                        WHERE o.servicio_id = $servicio_id");

while ($op = $resOps->fetch_assoc()) {
    $horas = 0;
    if ($op['fecha_inicio'] && $op['fecha_fin']) {
        $inicio = new DateTime($op['fecha_inicio']);
        $fin = new DateTime($op['fecha_fin']);
        $intervalo = $inicio->diff($fin);
        $horas = $intervalo->h + ($intervalo->i / 60) + ($intervalo->s / 3600) + ($intervalo->days * 24);
    }

    echo "Op ID: {$op['id']} | Técnico: {$op['nombre']} (ID: {$op['tecnico_responsable_id']}) | Esp ID: " . ($op['ID_ESPECIALIDAD'] ?? 'NULL') . " | Horas: " . round($horas, 2) . "\n";

    if ($op['ID_ESPECIALIDAD']) {
        $esp_id = $op['ID_ESPECIALIDAD'];
        // Tarifa cliente
        $resT = $conn->query("SELECT valor FROM cliente_perfiles WHERE cliente_id = $cliente_id AND especialidad_id = $esp_id");
        $t = $resT->fetch_assoc();
        echo "   -> Tarifa Cliente: " . ($t ? "$" . $t['valor'] : "No tiene tarifa específica") . "\n";

        // Tarifa base
        $resB = $conn->query("SELECT valor_hr FROM especialidades WHERE id = $esp_id");
        $b = $resB->fetch_assoc();
        echo "   -> Tarifa Base: " . ($b ? "$" . $b['valor_hr'] : "No tiene tarifa base") . "\n";
    }
}

echo "\n--- SNAPSHOT ACTUAL ---\n";
$resSnap = $conn->query("SELECT * FROM fac_control_servicios WHERE servicio_id = $servicio_id");
print_r($resSnap->fetch_assoc());
