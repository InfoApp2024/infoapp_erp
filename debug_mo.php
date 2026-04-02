<?php
require 'backend/conexion.php';

// Intentar deshabilitar el error de conexión si es por el host
error_reporting(E_ALL);
ini_set('display_errors', 1);

// Buscar ID interno de OT 1281 y 1282
$ots = ['1281', '1282'];
foreach ($ots as $no) {
    echo "\n=== ANALISIS OT #$no ===\n";
    $res = $conn->query("SELECT id, cliente_id, numero_orden FROM servicios WHERE numero_orden = '$no' OR numero_orden LIKE '%$no%' LIMIT 1");
    if (!$res) {
        echo "Error en query servicios: " . $conn->error . "\n";
        continue;
    }
    $s = $res->fetch_assoc();
    if (!$s) {
        echo "OT no encontrada\n";
        continue;
    }
    $sid = $s['id'];
    $cid = $s['cliente_id'];
    echo "Servicio ID: $sid | Cliente ID: $cid\n";

    // Ver snapshot
    $resSnap = $conn->query("SELECT * FROM fac_control_servicios WHERE servicio_id = $sid");
    $snap = $resSnap->fetch_assoc();
    if ($snap) {
        echo "Snapshot: Repuestos=" . $snap['total_repuestos'] . " | MO=" . $snap['total_mano_obra'] . " | Total=" . $snap['valor_snapshot'] . "\n";
    } else {
        echo "No hay snapshot persistido.\n";
    }

    // Ver operaciones
    $resOps = $conn->query("SELECT o.id, o.tecnico_responsable_id, o.fecha_inicio, o.fecha_fin, u.nombre, u.ID_ESPECIALIDAD 
                           FROM operaciones o 
                           LEFT JOIN usuarios u ON o.tecnico_responsable_id = u.id 
                           WHERE o.servicio_id = $sid");
    if (!$resOps) {
        echo "Error en query operaciones: " . $conn->error . "\n";
        continue;
    }
    echo "Operaciones registradas:\n";
    while ($op = $resOps->fetch_assoc()) {
        $inicio = $op['fecha_inicio'];
        $fin = $op['fecha_fin'];
        $esp = $op['ID_ESPECIALIDAD'] ?? 'NULL';
        $tecnico = $op['nombre'] ?? 'Desconocido';

        $horas = 0;
        if ($inicio && $fin) {
            $diff = (strtotime($fin) - strtotime($inicio)) / 3600;
            $horas = round($diff, 2);
        }

        // Tarifa
        $tarifa = 0;
        if ($esp != 'NULL') {
            $resT = $conn->query("SELECT valor FROM cliente_perfiles WHERE cliente_id = $cid AND especialidad_id = $esp");
            $tRow = $resT->fetch_assoc();
            $tarifa = $tRow ? $tRow['valor'] : 0;
            if ($tarifa == 0) {
                $resB = $conn->query("SELECT valor_hr FROM especialidades WHERE id = $esp");
                $bRow = $resB->fetch_assoc();
                $tarifa = $bRow ? $bRow['valor_hr'] : 0;
            }
        }

        echo "- ID: {$op['id']} | Técnico: $tecnico | Especialidad: $esp | Horas: $horas | Tarifa: $tarifa | Subtotal: " . ($horas * $tarifa) . " | Inicio: $inicio | Fin: $fin\n";
    }
}
