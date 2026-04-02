<?php
require_once 'conexion.php';

echo "--- REGLAS DE CAUSACION (GENERAR_FACTURA) ---\n";
$r = $conn->query("SELECT c.*, p.codigo_cuenta, p.nombre FROM fin_config_causacion c JOIN fin_puc p ON c.puc_cuenta_id = p.id WHERE c.evento_codigo = 'GENERAR_FACTURA' AND c.activo = 1");
while ($row = $r->fetch_assoc()) {
    echo "MOV: {$row['tipo_movimiento']} | BASE: {$row['base_calculo']} | %: {$row['porcentaje']} | CUENTA: {$row['codigo_cuenta']} ({$row['nombre']})\n";
}

echo "\n--- CUENTAS RELEVANTES EN EL PUC ---\n";
$q = "SELECT * FROM fin_puc WHERE codigo_cuenta IN ('130505', '413501', '413505', '240801', '240805', '135515', '135517', '135518')";
$r = $conn->query($q);
while ($row = $r->fetch_assoc()) {
    echo "CODE: {$row['codigo_cuenta']} | NAME: {$row['nombre']}\n";
}
$conn->close();
?>