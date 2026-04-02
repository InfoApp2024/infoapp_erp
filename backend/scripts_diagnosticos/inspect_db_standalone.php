<?php
$servername = "127.0.0.1";
$username = "u342171239_Test";
$password = "Test_2025/-*";
$database = "u342171239_InfoApp_Test";

$conn = new mysqli($servername, $username, $password, $database);

if ($conn->connect_error) {
    die("Connection failed: " . $conn->connect_error);
}

$tables = ['servicio_staff', 'servicio_repuestos', 'operaciones'];

foreach ($tables as $table) {
    echo "\n--- TABLE: $table ---\n";
    $result = $conn->query("DESCRIBE `$table` ");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "{$row['Field']} - {$row['Type']} - {$row['Null']} - {$row['Key']} - {$row['Extra']}\n";
        }
    }

    echo "\n--- INDEXES: $table ---\n";
    $result = $conn->query("SHOW INDEX FROM `$table` ");
    if ($result) {
        while ($row = $result->fetch_assoc()) {
            echo "{$row['Key_name']} - {$row['Column_name']} - Non_unique: {$row['Non_unique']}\n";
        }
    }
}
$conn->close();
