<?php
// API_Infoapp/login/permissions/diagnostico_duplicados_y_esquema.php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json; charset=utf-8');

try {
    require '../../conexion.php';

    $diagnostico = [
        'timestamp' => date('Y-m-d H:i:s'),
        'usuarios_duplicados' => [],
        'esquema_user_permissions' => []
    ];

    // 1. Buscar duplicados en usuarios
    $sqlDuplicados = "SELECT NOMBRE_USER, COUNT(*) as total, GROUP_CONCAT(id) as ids 
                      FROM usuarios 
                      GROUP BY NOMBRE_USER 
                      HAVING total > 1";
    $resDuplicados = $conn->query($sqlDuplicados);
    while ($row = $resDuplicados->fetch_assoc()) {
        $diagnostico['usuarios_duplicados'][] = $row;
    }

    // 2. Verificar esquema de permisos
    $resEsquema = $conn->query("DESCRIBE user_permissions");
    while ($row = $resEsquema->fetch_assoc()) {
        $diagnostico['esquema_user_permissions'][] = $row;
    }

    // 3. Recomendación
    $diagnostico['recomendacion'] = "Si hay duplicados, el login siempre tomará el primero (ID más bajo). Debes eliminar o renombrar los duplicados. Si las columnas de permisos son menores a 50, corres riesgo de truncamiento.";

    echo json_encode($diagnostico, JSON_PRETTY_PRINT);

} catch (Exception $e) {
    echo json_encode(['success' => false, 'error' => $e->getMessage()]);
} finally {
    if (isset($conn))
        $conn->close();
}
?>