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

// Obtener parámetros con validación
$nombre = isset($input['nombre_estado']) ? trim($input['nombre_estado']) : null;
$color = isset($input['color']) ? trim($input['color']) : null;
$modulo = isset($input['modulo']) ? trim($input['modulo']) : 'servicio';
$estado_base_codigo = isset($input['codigo_base']) ? trim($input['codigo_base']) : (isset($input['estado_base_codigo']) ? trim($input['estado_base_codigo']) : 'ABIERTO');
$bloquea_cierre = isset($input['bloquea_cierre']) ? (int) $input['bloquea_cierre'] : 0;
$orden = isset($input['orden']) ? (int) $input['orden'] : 0;

// Validar datos requeridos
if (!$nombre || !$color) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'nombre_estado y color son requeridos']);
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

// ✅ NUEVO: Verificar si las columnas de estado_base existen
$columnsExist = false;
$checkColumns = $conn->query("SHOW COLUMNS FROM estados_proceso LIKE 'estado_base_codigo'");
if ($checkColumns && $checkColumns->num_rows > 0) {
    $columnsExist = true;
}

// Si las columnas existen, validar estado_base_codigo
if ($columnsExist) {
    $check_stmt = $conn->prepare('SELECT codigo FROM estados_base WHERE codigo = ?');
    if ($check_stmt) {
        $check_stmt->bind_param('s', $estado_base_codigo);
        $check_stmt->execute();
        $check_result = $check_stmt->get_result();

        if ($check_result->num_rows === 0) {
            http_response_code(400);
            echo json_encode(['success' => false, 'message' => 'Estado base inválido: ' . $estado_base_codigo]);
            $check_stmt->close();
            $conn->close();
            exit;
        }
        $check_stmt->close();
    } else {
        http_response_code(500);
        echo json_encode(['success' => false, 'message' => 'Error al preparar consulta de validación de estado base: ' . $conn->error]);
        exit;
    }
}

// Preparar e insertar según disponibilidad de columnas
if ($columnsExist) {
    // Versión con estado base
    $stmt = $conn->prepare('INSERT INTO estados_proceso (nombre_estado, color, modulo, estado_base_codigo, bloquea_cierre, orden) VALUES (?, ?, ?, ?, ?, ?)');
} else {
    // Versión legacy sin estado base
    $stmt = $conn->prepare('INSERT INTO estados_proceso (nombre_estado, color, modulo, orden) VALUES (?, ?, ?, ?)');
}

if (!$stmt) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error al preparar consulta: ' . $conn->error]);
    exit;
}

$ifColumnsExistBind = $columnsExist;
if ($ifColumnsExistBind) {
    $stmt->bind_param('ssssii', $nombre, $color, $modulo, $estado_base_codigo, $bloquea_cierre, $orden);
} else {
    $stmt->bind_param('sssi', $nombre, $color, $modulo, $orden);
}

$ok = $stmt->execute();

if ($ok) {
    // Devolver éxito con el ID insertado
    echo json_encode(['success' => true, 'id' => $stmt->insert_id]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'No se pudo crear el estado: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>