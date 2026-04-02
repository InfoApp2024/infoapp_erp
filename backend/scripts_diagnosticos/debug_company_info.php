<?php
include 'conexion.php';
$res = $conn->query("SELECT NOMBRE_COMPLETO, EMAIL, DOCUMENTO_NIT FROM usuarios WHERE TIPO_ROL = 'admin' LIMIT 1");
if ($res && $row = $res->fetch_assoc()) {
    echo "USER_COMPANY_INFO_START\n";
    echo json_encode($row);
    echo "\nUSER_COMPANY_INFO_END\n";
}
$conn->close();
