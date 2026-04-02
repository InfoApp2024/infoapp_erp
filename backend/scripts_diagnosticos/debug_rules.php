<?php
require 'conexion.php';
$res = $conn->query("SELECT c.*, p.codigo_cuenta, p.nombre as cuenta_nombre 
                    FROM fin_config_causacion c 
                    JOIN fin_puc p ON c.puc_cuenta_id = p.id 
                    WHERE c.evento_codigo = 'GENERAR_FACTURA' AND c.activo = 1");
while ($row = $res->fetch_assoc()) {
    echo json_encode($row) . "\n";
}
?>