<?php
require 'conexion.php';

echo "<h1>Diagnóstico de Datos para Filtrado v2</h1>";

// 1. Resumen de Empresas en Equipos
echo "<h2>1. Resumen de Empresas en Equipos</h2>";
$sql = "SELECT nombre_empresa, COUNT(*) as cantidad FROM equipos GROUP BY nombre_empresa";
$result = $conn->query($sql);
echo "<table border='1'><tr><th>Empresa (en equipos)</th><th>Cantidad de Equipos</th></tr>";
while ($row = $result->fetch_assoc()) {
    $emp = $row["nombre_empresa"] === null ? "NULL" : ($row["nombre_empresa"] === "" ? "VACIO" : "[" . $row["nombre_empresa"] . "]");
    echo "<tr><td>" . $emp . "</td><td>" . $row["cantidad"] . "</td></tr>";
}
echo "</table>";

// 2. Resumen de Empresas en Funcionarios
echo "<h2>2. Resumen de Empresas en Funcionarios</h2>";
$sql = "SELECT empresa, COUNT(*) as cantidad FROM funcionario GROUP BY empresa";
$result = $conn->query($sql);
echo "<table border='1'><tr><th>Empresa (en funcionarios)</th><th>Cantidad de Funcionarios</th></tr>";
while ($row = $result->fetch_assoc()) {
    $emp = $row["empresa"] === null ? "NULL" : ($row["empresa"] === "" ? "VACIO" : "[" . $row["empresa"] . "]");
    echo "<tr><td>" . $emp . "</td><td>" . $row["cantidad"] . "</td></tr>";
}
echo "</table>";

// 3. Simulación de Filtro
echo "<h2>3. Simulación de Filtro LIKE (Capa Backend)</h2>";
$test_companies = ['ARGOS', 'Argos', 'SOCIEDAD PORTUARIA', 'INFOAPP'];
foreach ($test_companies as $test_emp) {
    $like_emp = "%" . $test_emp . "%";
    $stmt = $conn->prepare("SELECT COUNT(*) as total FROM funcionario WHERE activo = 1 AND empresa LIKE ?");
    $stmt->bind_param("s", $like_emp);
    $stmt->execute();
    $res = $stmt->get_result()->fetch_assoc();
    echo "Filtro por <b>[$test_emp]</b> -> Encontró <b>" . $res['total'] . "</b> funcionarios.<br>";
}

// 4. Detalle de equipo específico
if (isset($_GET['equipo_id'])) {
    $eq_id = (int) $_GET['equipo_id'];
    echo "<h2>4. Detalle del Equipo $eq_id</h2>";
    $sql = "SELECT id, nombre, nombre_empresa FROM equipos WHERE id = $eq_id";
    $result = $conn->query($sql);
    if ($row = $result->fetch_assoc()) {
        echo "Nombre: " . $row['nombre'] . "<br>";
        echo "Empresa: [" . $row['nombre_empresa'] . "]<br>";
    } else {
        echo "Equipo no encontrado.<br>";
    }
} else {
    echo "<h2>4. Detalle de equipo (Opcional)</h2>";
    echo "Agrega ?equipo_id=XXX a la URL para ver un equipo específico.<br>";
}

$conn->close();
?>