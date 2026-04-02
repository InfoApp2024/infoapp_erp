<?php
// backend/operaciones/verificar_db.php
require dirname(__FILE__) . '/../conexion.php';

$resumen = [];

// 1. Verificar tabla operaciones
$check_table = $conn->query("SHOW TABLES LIKE 'operaciones'");
$resumen['tabla_operaciones'] = ($check_table && $check_table->num_rows > 0);

if ($resumen['tabla_operaciones']) {
    $columns = $conn->query("SHOW COLUMNS FROM operaciones");
    $col_list = [];
    while ($col = $columns->fetch_assoc()) {
        $col_list[] = $col['Field'];
    }
    $resumen['columnas_operaciones'] = $col_list;
}

// 2. Verificar columnas en servicio_repuestos
$check_repuestos = $conn->query("SHOW COLUMNS FROM servicio_repuestos LIKE 'operacion_id'");
$resumen['columna_repuestos_operacion_id'] = ($check_repuestos && $check_repuestos->num_rows > 0);

// 3. Verificar columnas en servicio_staff
$check_staff = $conn->query("SHOW COLUMNS FROM servicio_staff LIKE 'operacion_id'");
$resumen['columna_staff_operacion_id'] = ($check_staff && $check_staff->num_rows > 0);

header('Content-Type: application/json');
echo json_encode($resumen, JSON_PRETTY_PRINT);
?>