<?php
require_once __DIR__ . '/../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $currentUser = requireAuth();
    require '../conexion.php'; // Usamos $conn (MySQLi)

    // Validar permiso
    requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'crear', $currentUser['rol']);

    $data = json_decode(file_get_contents('php://input'), true);

    if (empty($data['actividad'])) {
        throw new Exception('El nombre de la actividad es requerido');
    }

    $actividad = trim($data['actividad']);
    $activo = isset($data['activo']) ? (bool) $data['activo'] : true;

    // Nuevos campos
    $cant_hora = isset($data['cant_hora']) ? (float) $data['cant_hora'] : 0.00;
    $num_tecnicos = isset($data['num_tecnicos']) ? (int) $data['num_tecnicos'] : 1;
    $id_user = isset($data['id_user']) ? (int) $data['id_user'] : null;
    $sistema_id = isset($data['sistema_id']) ? (int) $data['sistema_id'] : null;

    if (strlen($actividad) < 3) {
        throw new Exception('La actividad debe tener al menos 3 caracteres');
    }

    if (strlen($actividad) > 255) {
        throw new Exception('La actividad no puede exceder 255 caracteres');
    }

    if ($num_tecnicos < 1) {
        throw new Exception('El número de técnicos debe ser al menos 1');
    }

    // Verificar si ya existe
    $sqlCheck = "SELECT id FROM actividades_estandar WHERE actividad = ?";
    $stmtCheck = $conn->prepare($sqlCheck);
    $stmtCheck->bind_param("s", $actividad);
    $stmtCheck->execute();
    $stmtCheck->store_result();  // Almacenar resultados para num_rows

    if ($stmtCheck->num_rows > 0) {
        throw new Exception('Ya existe una actividad con ese nombre');
    }

    // Insertar nueva actividad
    $sql = "INSERT INTO actividades_estandar (actividad, activo, cant_hora, num_tecnicos, id_user, sistema_id) VALUES (?, ?, ?, ?, ?, ?)";
    $stmt = $conn->prepare($sql);
    $activoInt = $activo ? 1 : 0;
    $stmt->bind_param("sidiii", $actividad, $activoInt, $cant_hora, $num_tecnicos, $id_user, $sistema_id);
    $stmt->execute();

    $id = $stmt->insert_id;

    // Obtener la actividad creada
    $sqlGet = "SELECT * FROM actividades_estandar WHERE id = ?";
    $stmtGet = $conn->prepare($sqlGet);
    $stmtGet->bind_param("i", $id);
    $stmtGet->execute();
    $result = $stmtGet->get_result();
    $actividadCreada = $result->fetch_assoc();

    // Convertir tipos
    $actividadCreada['id'] = (int) $actividadCreada['id'];
    $actividadCreada['activo'] = (bool) $actividadCreada['activo'];
    $actividadCreada['cant_hora'] = (float) $actividadCreada['cant_hora'];
    $actividadCreada['num_tecnicos'] = (int) $actividadCreada['num_tecnicos'];
    $actividadCreada['id_user'] = $actividadCreada['id_user'] ? (int) $actividadCreada['id_user'] : null;
    $actividadCreada['sistema_id'] = $actividadCreada['sistema_id'] ? (int) $actividadCreada['sistema_id'] : null;

    echo json_encode([
        'success' => true,
        'message' => 'Actividad creada exitosamente',
        'data' => $actividadCreada
    ]);
} catch (Exception $e) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => 'Error al crear actividad estándar',
        'error' => $e->getMessage()
    ]);
} finally {
    // Cerrar solo las sentencias que están abiertas
    if (isset($stmtCheck) && is_object($stmtCheck))
        $stmtCheck->close();
    if (isset($stmt) && is_object($stmt))
        $stmt->close();
    if (isset($stmtGet) && is_object($stmtGet))
        $stmtGet->close();

    // Cerrar conexión
    if (isset($conn) && $conn instanceof mysqli)
        $conn->close();
}
