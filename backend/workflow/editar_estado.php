<?php
header("Access-Control-Allow-Origin: *");
header("Access-Control-Allow-Headers: Content-Type, Authorization");
header("Access-Control-Allow-Methods: POST, OPTIONS");
header('Content-Type: application/json; charset=utf-8');

// IMPORTANTE: Manejar petición OPTIONS para CORS
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

// Decodificar JSON como array asociativo
$input = json_decode(file_get_contents('php://input'), true);

// Obtener parámetros
$id = isset($input['id']) ? intval($input['id']) : 0;
$nombre = isset($input['nombre_estado']) ? trim($input['nombre_estado']) : null;
$color = array_key_exists('color', $input) ? trim($input['color']) : null;

// Validar que hay ID válido y al menos un campo a actualizar
if ($id <= 0 || (!$nombre && $color === null)) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'id válido y al menos un campo a actualizar']);
    exit;
}

// Conexión
require '../conexion.php';

// Verificar conexión
if ($conn->connect_errno) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'DB connection error']);
    exit;
}

// Configurar charset
$conn->set_charset('utf8mb4');

// Construir consulta dinámica según campos proporcionados
$sets = [];
$params = [];
$types = '';

if ($nombre) {
    $sets[] = 'nombre_estado = ?';
    $params[] = $nombre;
    $types .= 's';
}
if ($color !== null) {
    $sets[] = 'color = ?';
    $params[] = $color;
    $types .= 's';
}

// ✅ NUEVO: Soporte para estado base y bloqueo de cierre
if (isset($input['codigo_base'])) {
    $sets[] = 'estado_base_codigo = ?';
    $params[] = trim($input['codigo_base']);
    $types .= 's';
} elseif (isset($input['estado_base_codigo'])) {
    $sets[] = 'estado_base_codigo = ?';
    $params[] = trim($input['estado_base_codigo']);
    $types .= 's';
}

if (isset($input['bloquea_cierre'])) {
    $sets[] = 'bloquea_cierre = ?';
    $params[] = (int) $input['bloquea_cierre'];
    $types .= 'i';
}
if (isset($input['orden'])) {
    $sets[] = 'orden = ?';
    $params[] = (int) $input['orden'];
    $types .= 'i';
}

// Agregar el ID al final
$types .= 'i';
$params[] = $id;

// Construir y ejecutar consulta
$sql = 'UPDATE estados_proceso SET ' . implode(', ', $sets) . ' WHERE id = ?';
$stmt = $conn->prepare($sql);
$stmt->bind_param($types, ...$params);
$ok = $stmt->execute();

if ($ok) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'No se pudo editar el estado']);
}

$stmt->close();
$conn->close();
?>