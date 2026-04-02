<?php
// API_Infoapp/login/permissions/migrar_esquema_permisos_v2.php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json; charset=utf-8');

try {
    require '../../conexion.php';

    $results = [];

    // 1. Corregir longitud de module
    $sqlModule = "ALTER TABLE user_permissions MODIFY COLUMN module VARCHAR(50) NOT NULL";
    if ($conn->query($sqlModule)) {
        $results['module_column'] = "Actualizada a VARCHAR(50)";
    } else {
        $results['module_column'] = "Error: " . $conn->error;
    }

    // 2. Corregir longitud de action
    $sqlAction = "ALTER TABLE user_permissions MODIFY COLUMN action VARCHAR(50) NOT NULL";
    if ($conn->query($sqlAction)) {
        $results['action_column'] = "Actualizada a VARCHAR(50)";
    } else {
        $results['action_column'] = "Error: " . $conn->error;
    }

    // 3. Nota sobre la unicidad de usuarios
    $results['siguiente_paso'] = "Una vez eliminados los duplicados (usa el script de diagnóstico), se recomienda ejecutar: ALTER TABLE usuarios ADD UNIQUE INDEX ux_nombre_user (NOMBRE_USER)";

    echo json_encode(['success' => true, 'results' => $results]);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} finally {
    if (isset($conn))
        $conn->close();
}
?>