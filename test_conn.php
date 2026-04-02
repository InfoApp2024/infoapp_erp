<?php
// test_conn.php
$servername = "127.0.0.1";
$username = "u342171239_Test";
$password = "Test_2025/-*";
$database = "u342171239_InfoApp_Test";

try {
    $conn = new mysqli($servername, $username, $password, $database);
    if ($conn->connect_error) {
        echo "Error: " . $conn->connect_error;
    } else {
        echo "Success";
    }
} catch (Exception $e) {
    echo "Exception: " . $e->getMessage();
}
?>