<?php
require __DIR__ . '/../conexion.php';

echo "--- Verificando Transiciones de Estado ---\n";

$result = $conn->query("
    SELECT t.id, 
           eo.nombre_estado as 'Origen', 
           ed.nombre_estado as 'Destino', 
           t.nombre as 'Nombre Transicion', 
           t.trigger_code as 'Trigger'
    FROM transiciones_estado t
    JOIN estados_proceso eo ON t.estado_origen_id = eo.id
    JOIN estados_proceso ed ON t.estado_destino_id = ed.id
    WHERE t.modulo = 'servicio'
");

if (!$result) {
    die("Error en query: " . $conn->error);
}

while ($row = $result->fetch_assoc()) {
    printf(
        "[%d] %s -> %s | Transicion: %s | Trigger: %s\n",
        $row['id'],
        $row['Origen'],
        $row['Destino'],
        $row['Nombre Transicion'],
        $row['Trigger']
    );
}

$conn->close();
?>