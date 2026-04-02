<?php
require_once 'backend/conexion.php';
require_once 'backend/login/auth_middleware.php';
$currentUser = requireAuth();

$result = $conn->query("DESCRIBE branding");
while($row = $result->fetch_assoc()) {
    print_r($row);
}
