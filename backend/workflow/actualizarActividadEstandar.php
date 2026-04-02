<?php
require_once __DIR__ . '/../login/auth_middleware.php';

header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: POST, PUT, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Manejar preflight request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require '../conexion.php'; // Usamos $conn (MySQLi)

try {
    $currentUser = requireAuth();

    // Verificar que la conexión existe
    if (!isset($conn) || !$conn instanceof mysqli) {
        throw new Exception('Conexión a base de datos no disponible');
    }

    // Validar permiso
    requirePermission($conn, $currentUser['id'], 'servicios_actividades', 'actualizar', $currentUser['rol']);

    // Verificar método HTTP
    if ($_SERVER['REQUEST_METHOD'] !== 'POST' && $_SERVER['REQUEST_METHOD'] !== 'PUT') {
        throw new Exception('Método no permitido: ' . $_SERVER['REQUEST_METHOD']);
    }

    $data = json_decode(file_get_contents('php://input'), true);

    // Debug de datos recibidos
    error_log("DEBUG actualizarActividad - Datos recibidos: " . json_encode($data));
    error_log("DEBUG actualizarActividad - Método HTTP: " . $_SERVER['REQUEST_METHOD']);

    // Validaciones
    if (empty($data['id'])) {
        throw new Exception('ID de actividad es requerido');
    }

    if (empty($data['actividad'])) {
        throw new Exception('El nombre de la actividad es requerido');
    }

    $id = (int) $data['id'];
    $actividad = trim($data['actividad']);
    $activo = isset($data['activo']) ? (int) $data['activo'] : 1;
    $cant_hora = isset($data['cant_hora']) ? (float) $data['cant_hora'] : 0.00;
    $num_tecnicos = isset($data['num_tecnicos']) ? (int) $data['num_tecnicos'] : 1;
    $id_user = isset($data['id_user']) ? (int) $data['id_user'] : null;
    $sistema_id = isset($data['sistema_id']) ? (int) $data['sistema_id'] : null;

    // Validar longitud
    if (strlen($actividad) < 3) {
        throw new Exception('La actividad debe tener al menos 3 caracteres');
    }

    if (strlen($actividad) > 255) {
        throw new Exception('La actividad no puede exceder 255 caracteres');
    }

    if ($num_tecnicos < 1) {
        throw new Exception('El número de técnicos debe ser al menos 1');
    }

    // Verificar que existe
    $sqlCheck = "SELECT id FROM actividades_estandar WHERE id = ?";
    $stmtCheck = $conn->prepare($sqlCheck);
    if (!$stmtCheck) {
        throw new Exception('Error preparando consulta de verificación: ' . $conn->error);
    }

    $stmtCheck->bind_param("i", $id);
    $stmtCheck->execute();
    $stmtCheck->store_result();

    if ($stmtCheck->num_rows == 0) {
        $stmtCheck->close();
        throw new Exception('La actividad no existe');
    }
    $stmtCheck->close();

    // Verificar duplicados (excluyendo el actual)
    $sqlDuplicate = "SELECT id FROM actividades_estandar 
                     WHERE LOWER(actividad) = LOWER(?) AND id != ?";
    $stmtDuplicate = $conn->prepare($sqlDuplicate);
    if (!$stmtDuplicate) {
        throw new Exception('Error preparando consulta de duplicados: ' . $conn->error);
    }

    $stmtDuplicate->bind_param("si", $actividad, $id);
    $stmtDuplicate->execute();
    $stmtDuplicate->store_result();

    if ($stmtDuplicate->num_rows > 0) {
        $stmtDuplicate->close();
        throw new Exception('Ya existe otra actividad con ese nombre');
    }
    $stmtDuplicate->close();

    // Actualizar
    $sql = "UPDATE actividades_estandar 
            SET actividad = ?, 
                activo = ?,
                cant_hora = ?,
                num_tecnicos = ?,
                id_user = ?,
                sistema_id = ?,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = ?";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception('Error preparando actualización: ' . $conn->error);
    }

    $stmt->bind_param("sidiiii", $actividad, $activo, $cant_hora, $num_tecnicos, $id_user, $sistema_id, $id);
    $result = $stmt->execute();

    // Debug del resultado de la actualización
    error_log("DEBUG actualizarActividad - Filas afectadas: " . $stmt->affected_rows);

    if (!$result) {
        $error = $stmt->error;
        $stmt->close();
        throw new Exception('Error ejecutando la actualización: ' . $error);
    }

    $stmt->close();

    // Obtener la actividad actualizada
    $sqlGet = "SELECT * FROM actividades_estandar WHERE id = ?";
    $stmtGet = $conn->prepare($sqlGet);
    if (!$stmtGet) {
        throw new Exception('Error preparando consulta de obtención: ' . $conn->error);
    }

    $stmtGet->bind_param("i", $id);
    $stmtGet->execute();
    $resultGet = $stmtGet->get_result();
    $actividadActualizada = $resultGet->fetch_assoc();
    $stmtGet->close();

    if (!$actividadActualizada) {
        throw new Exception('No se pudo obtener la actividad actualizada');
    }

    // Convertir tipos
    $actividadActualizada['id'] = (int) $actividadActualizada['id'];
    $actividadActualizada['activo'] = (bool) $actividadActualizada['activo'];
    $actividadActualizada['cant_hora'] = (float) $actividadActualizada['cant_hora'];
    $actividadActualizada['num_tecnicos'] = (int) $actividadActualizada['num_tecnicos'];
    $actividadActualizada['id_user'] = $actividadActualizada['id_user'] ? (int) $actividadActualizada['id_user'] : null;
    $actividadActualizada['sistema_id'] = $actividadActualizada['sistema_id'] ? (int) $actividadActualizada['sistema_id'] : null;

    // Debug de la respuesta
    error_log("DEBUG actualizarActividad - Respuesta: " . json_encode($actividadActualizada));

    echo json_encode([
        'success' => true,
        'message' => 'Actividad actualizada exitosamente',
        'data' => $actividadActualizada
    ]);

} catch (Exception $e) {
    error_log("ERROR actualizarActividad: " . $e->getMessage());
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
} finally {
    // Cerrar conexión si aún está abierta
    if (isset($conn) && $conn instanceof mysqli) {
        $conn->close();
    }
}
?>