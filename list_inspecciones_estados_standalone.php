<?php
$servername = "localhost";
$username = "u342171239_Test";
$password = "Test_2025/-*";
$database = "u342171239_InfoApp_Test";

$conn = new mysqli($servername, $username, $password, $database);
if ($conn->connect_error) {
    die("Error de conexión: " . $conn->connect_error);
}

$stmt = $conn->prepare('SELECT id, nombre_estado, color FROM estados_proceso WHERE modulo = ? ORDER BY id ASC');
$modulo = 'inspecciones';
$stmt->bind_param('s', $modulo);
$stmt->execute();
$res = $stmt->get_result();
while ($row = $res->fetch_assoc()) {
    echo "ID: " . $row['id'] . " - Nombre: " . $row['nombre_estado'] . "\n";
}
$conn->close();
?>