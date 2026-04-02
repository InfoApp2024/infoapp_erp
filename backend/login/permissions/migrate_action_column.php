<?php
// API_Infoapp/login/permissions/migrate_action_column.php
// Migración: Aumentar tamaño de columna action en user_permissions
// Ejecutar UNA SOLA VEZ en el servidor de producción

error_reporting(E_ALL);
ini_set('display_errors', 1);

header('Content-Type: application/json; charset=utf-8');

// SEGURIDAD: Solo permitir ejecución desde localhost o con token especial
$allowedIPs = ['127.0.0.1', '::1'];
$clientIP = $_SERVER['REMOTE_ADDR'] ?? '';

// Token de seguridad (cambiar por uno aleatorio)
$securityToken = $_GET['token'] ?? '';
$validToken = 'MIGRATION_2026_02_04_PERMISSIONS'; // Cambiar esto

if (!in_array($clientIP, $allowedIPs) && $securityToken !== $validToken) {
    http_response_code(403);
    echo json_encode([
        'success' => false,
        'error' => 'Acceso denegado. Esta migración solo puede ejecutarse desde localhost o con token válido.'
    ]);
    exit;
}

try {
    require '../../conexion.php';

    echo json_encode([
        'step' => 1,
        'message' => 'Conexión a base de datos establecida'
    ]) . "\n";

    // Paso 1: Verificar estructura actual
    $result = $conn->query("DESCRIBE user_permissions");
    $currentStructure = [];
    while ($row = $result->fetch_assoc()) {
        $currentStructure[] = $row;
        if ($row['Field'] === 'action') {
            echo json_encode([
                'step' => 2,
                'message' => 'Estructura actual de columna action',
                'data' => $row
            ]) . "\n";
        }
    }

    // Paso 2: Verificar si ya se aplicó la migración
    $actionColumn = null;
    foreach ($currentStructure as $col) {
        if ($col['Field'] === 'action') {
            $actionColumn = $col;
            break;
        }
    }

    if (!$actionColumn) {
        throw new Exception('Columna action no encontrada en user_permissions');
    }

    // Verificar si ya es VARCHAR(50)
    if (stripos($actionColumn['Type'], 'varchar(50)') !== false) {
        echo json_encode([
            'success' => true,
            'message' => 'La migración ya fue aplicada anteriormente. La columna action ya es VARCHAR(50).',
            'current_type' => $actionColumn['Type']
        ]);
        exit;
    }

    echo json_encode([
        'step' => 3,
        'message' => 'Iniciando migración...',
        'current_type' => $actionColumn['Type']
    ]) . "\n";

    // Paso 3: Ejecutar ALTER TABLE
    $sql = "ALTER TABLE user_permissions MODIFY COLUMN action VARCHAR(50) NOT NULL";

    if (!$conn->query($sql)) {
        throw new Exception('Error al modificar columna: ' . $conn->error);
    }

    echo json_encode([
        'step' => 4,
        'message' => 'Columna modificada exitosamente'
    ]) . "\n";

    // Paso 4: Verificar el cambio
    $result = $conn->query("DESCRIBE user_permissions");
    $newStructure = [];
    while ($row = $result->fetch_assoc()) {
        if ($row['Field'] === 'action') {
            $newStructure = $row;
            break;
        }
    }

    echo json_encode([
        'step' => 5,
        'message' => 'Nueva estructura de columna action',
        'data' => $newStructure
    ]) . "\n";

    // Paso 5: Resultado final
    echo json_encode([
        'success' => true,
        'message' => 'Migración completada exitosamente',
        'before' => $actionColumn['Type'],
        'after' => $newStructure['Type'],
        'timestamp' => date('Y-m-d H:i:s')
    ]);

} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'error' => $e->getMessage(),
        'timestamp' => date('Y-m-d H:i:s')
    ]);
} finally {
    if (isset($conn)) {
        $conn->close();
    }
}
?>