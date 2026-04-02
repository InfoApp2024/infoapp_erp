<?php
require 'conexion.php';
$res = $conn->query('DESCRIBE fac_control_servicios');
while ($row = $res->fetch_assoc()) {
    print_r($row);
}
