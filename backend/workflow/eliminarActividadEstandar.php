<?php
require_once __DIR__ . '/../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: DELETE, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Manejar preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $currentUser = requireAuth();
    require_once '../conexion.php';

    // Validar permiso
    requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'eliminar', $currentUser['rol']);

    $id = isset($_GET['id']) ? (int) $_GET['id'] : 0;

    if ($id <= 0) {
        throw new Exception('ID de actividad inválido');
    }

    // Verificar que existe
    $sqlCheck = "SELECT actividad FROM actividades_estandar WHERE id = ?";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("i", $id);
    $stmtCheck->execute();
    $resultCheck = $stmtCheck->get_result();
    $actividad = $resultCheck->fetch_assoc();
    $stmtCheck->close();

    if (!$actividad) {
        throw new Exception('La actividad no existe');
    }

    // Verificar si está siendo usada por algún servicio
    $sqlServiciosCheck = "SELECT COUNT(*) as total 
                          FROM servicios 
                          WHERE actividad_id = ?";
    $stmtServiciosCheck = $conn->prepare($sqlServiciosCheck);
    $stmtServiciosCheck->bind_param("i", $id);
    $stmtServiciosCheck->execute();
    $resultServiciosCheck = $stmtServiciosCheck->get_result();
    $serviciosCount = $resultServiciosCheck->fetch_assoc();
    $stmtServiciosCheck->close();

    if ($serviciosCount['total'] > 0) {
        throw new Exception("No se puede eliminar la actividad porque está asignada a {$serviciosCount['total']} servicio(s)");
    }

    // Eliminar la actividad
    $sql = "DELETE FROM actividades_estandar WHERE id = ?";
    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $id);

    if ($stmt->execute()) {
        $stmt->close();

        echo json_encode([
            'success' => true,
            'message' => 'Actividad eliminada exitosamente',
            'data' => [
                'id' => $id,
                'actividad' => $actividad['actividad']
            ]
        ]);
    } else {
        throw new Exception('Error al eliminar la actividad');
    }

} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Error al eliminar actividad estándar',
        'error' => $e->getMessage()
    ]);
}

$conn->close();
?>