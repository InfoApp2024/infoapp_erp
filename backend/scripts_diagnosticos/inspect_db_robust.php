<?php
mysqli_report(MYSQLI_REPORT_ALL ^ MYSQLI_REPORT_INDEX);
$servername = "127.0.0.1";
$username = "u342171239_Test";
$password = "Test_2025/-*";
$database = "u342171239_InfoApp_Test";

try {
    $conn = new mysqli($servername, $username, $password);
    if ($conn->connect_error) {
        die("Connection failed: " . $conn->connect_error);
    }

    if (!$conn->select_db($database)) {
        echo "Database select failed: " . $conn->error . "\n";
        // List databases to see what's available
        $res = $conn->query("SHOW DATABASES");
        echo "Available databases:\n";
        while ($row = $res->fetch_row())
            echo "- $row[0]\n";
        die();
    }

    echo "Successfully connected to $database\n";

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
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
