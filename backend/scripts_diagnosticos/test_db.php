<?php
mysqli_report(MYSQLI_REPORT_ALL);
try {
    require 'conexion.php';
    echo "Conexión exitosa a la base de datos: " . $database . "\n";
    $result = $conn->query("SELECT 1");
    if ($result) {
        echo "Query de prueba exitosa.\n";
    }
} catch (mysqli_sql_exception $e) {
    echo "Error MySQLi: " . $e->getMessage() . "\n";
} catch (Exception $e) {
    echo "Error: " . $e->getMessage() . "\n";
}
?>