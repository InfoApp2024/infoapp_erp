<?php
// fix_base_states.php
require 'backend/conexion.php';

$states = [
    ['ABIERTO', 'Abierto', 'Servicio registrado, pendiente de programación o asignación', 0, 1, 1],
    ['PROGRAMADO', 'Programado', 'Servicio programado para atención en fecha específica', 0, 1, 2],
    ['ASIGNADO', 'Asignado', 'Servicio asignado a técnico o responsable', 0, 1, 3],
    ['EN_EJECUCION', 'En Ejecución', 'Servicio en proceso de ejecución o atención', 0, 1, 4],
    ['FINALIZADO', 'Finalizado', 'Servicio completado técnicamente, pendiente de cierre administrativo', 1, 0, 5],
    ['CERRADO', 'Cerrado', 'Servicio cerrado administrativamente, proceso completo', 1, 0, 6],
    ['CANCELADO', 'Cancelado', 'Servicio cancelado o anulado', 1, 0, 7]
];

echo "=== VERIFICANDO ESTADOS BASE ===\n";

foreach ($states as $s) {
    $stmt = $conn->prepare("INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) 
                          VALUES (?, ?, ?, ?, ?, ?) 
                          ON DUPLICATE KEY UPDATE nombre=VALUES(nombre), descripcion=VALUES(descripcion)");
    $stmt->bind_param("sssiii", $s[0], $s[1], $s[2], $s[3], $s[4], $s[5]);
    if ($stmt->execute()) {
        echo "Estado [{$s[0]}] procesado correctamente.\n";
    } else {
        echo "Error en [{$s[0]}]: " . $stmt->error . "\n";
    }
    $stmt->close();
}

$conn->close();
echo "=== PROCESO COMPLETADO ===\n";
?>