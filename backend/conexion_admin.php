<?php
$servername = "localhost"; // Sigue siendo localhost en Hostinger
$username = "u342171239_Admin_dev"; // Usuario completo con prefijo
$password = "Dev_2025/-*"; // Contraseña completa
$database = "u342171239_admin_infoapp"; // Nombre completo de la base de datos

$conn_admin = new mysqli($servername, $username, $password, $database);
if ($conn_admin->connect_error) {
    die("Error de conexión a la base admin_infoapp: " . $conn_admin->connect_error);
}
?>