<?php
require 'backend/conexion.php';

$id_a_probar = isset($_GET['id']) ? intval($_GET['id']) : 10; // Ejemplo

echo "Verificando uso del estado ID: $id_a_probar\n\n";

// 1. Verificar en Servicios
$stmt = $conn->prepare("SELECT COUNT(*) as cuenta FROM servicios WHERE estado_id = ?");
$stmt->bind_param("i", $id_a_probar);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();
echo "Uso en Servicios: " . $res['cuenta'] . "\n";

// 2. Verificar en Equipos
$stmt = $conn->prepare("SELECT COUNT(*) as cuenta FROM equipo WHERE estado_id = ?");
$stmt->bind_param("i", $id_a_probar);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();
echo "Uso en Equipos: " . $res['cuenta'] . "\n";

// 3. Verificar en Inspecciones
$stmt = $conn->prepare("SELECT COUNT(*) as cuenta FROM inspecciones_cabecera WHERE estado_id = ?");
$stmt->bind_param("i", $id_a_probar);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();
echo "Uso en Inspecciones: " . $res['cuenta'] . "\n";

$conn->close();
?>