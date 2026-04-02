<?php
// backend/geocercas/cron_cierre_automatico.php
// Este script está diseñado para ser ejecutado por una tarea programada (Cron Job)
// Se recomienda ejecutarlo una vez al día (ej. 3:00 AM) o cada hora.

error_reporting(E_ALL);
ini_set('display_errors', 1);

require '../conexion.php';

// 1. Verificar y crear columna 'observaciones' si no existe
$checkCol = $conn->query("SHOW COLUMNS FROM registros_geocerca LIKE 'observaciones'");
if ($checkCol->num_rows == 0) {
  $conn->query("ALTER TABLE registros_geocerca ADD COLUMN observaciones VARCHAR(255) NULL");
  echo "Columna 'observaciones' agregada a la tabla.\n";
}

// 2. Configurar zona horaria
date_default_timezone_set('America/Bogota');
$ahora = date('Y-m-d H:i:s');

// 3. Cerrar registros abiertos antiguos
// Criterio: Registros abiertos con más de 12 horas de antigüedad
$horas_limite = 12;

$sql = "UPDATE registros_geocerca 
        SET fecha_salida = ?, 
            observaciones = 'Cierre automático por sistema (Sin salida registrada)'
        WHERE fecha_salida IS NULL 
        AND fecha_ingreso < DATE_SUB(NOW(), INTERVAL ? HOUR)";

$stmt = $conn->prepare($sql);
$stmt->bind_param("si", $ahora, $horas_limite);

if ($stmt->execute()) {
  $afectados = $stmt->affected_rows;
  echo "Proceso completado.\n";
  echo "Fecha de ejecución: $ahora\n";
  echo "Registros cerrados automáticamente: $afectados\n";
} else {
  echo "Error al ejecutar el cierre automático: " . $stmt->error . "\n";
}

$conn->close();
