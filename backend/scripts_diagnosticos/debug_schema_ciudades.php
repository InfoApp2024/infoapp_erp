<?php
require 'conexion.php';

echo "--- Schema for table 'ciudades' ---\n";
$result = $conn->query("DESCRIBE ciudades");
while ($row = $result->fetch_assoc()) {
    print_r($row);
}

echo "\n--- Sample Data (Atlántico) ---\n";
$result = $conn->query("SELECT * FROM ciudades WHERE departamento LIKE '%Atlántico%' LIMIT 5");
while ($row = $result->fetch_assoc()) {
    print_r($row);
}

echo "\n--- Departments ---\n";
$result = $conn->query("SELECT * FROM departamentos WHERE nombre LIKE '%Atlántico%'");
while ($row = $result->fetch_assoc()) {
    print_r($row);
}
?>
