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
$origen = isset($input['estado_origen_id']) ? intval($input['estado_origen_id']) : 0;
$destino = isset($input['estado_destino_id']) ? intval($input['estado_destino_id']) : 0;
$modulo = isset($input['modulo']) ? trim($input['modulo']) : 'servicio';

// Validar IDs
if ($origen <= 0 || $destino <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'IDs de origen y destino válidos requeridos']);
    exit;
}

// Conexión
try {
    require '../conexion.php';
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error de conexión: ' . $e->getMessage()]);
    exit;
}

// Verificar conexión
if (!isset($conn) || $conn->connect_errno) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'DB connection error']);
    exit;
}

// Configurar charset
$conn->set_charset('utf8mb4');

// Obtener parámetros opcionales
$nombre = isset($input['nombre']) ? trim($input['nombre']) : 'Transición';
$trigger_code = isset($input['trigger_code']) ? trim($input['trigger_code']) : 'MANUAL';

// Validar que ambos estados existen y pertenecen al módulo especificado
$chk = $conn->prepare('SELECT COUNT(*) AS c FROM estados_proceso WHERE modulo = ? AND id IN (?, ?)');

if (!$chk) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error al preparar consulta de validación de estados: ' . $conn->error]);
    $conn->close();
    exit;
}

$chk->bind_param('sii', $modulo, $origen, $destino);
$chk->execute();
$res = $chk->get_result()->fetch_assoc();
$chk->close();

// Verificar que encontró exactamente 2 estados (origen y destino)
if (!$res || intval($res['c']) !== 2) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'Los estados no pertenecen al módulo o no existen']);
    $conn->close();
    exit;
}

// ✅ VALIDACIÓN DE TRIGGER ÚNICO (Si no es MANUAL)
if ($trigger_code !== 'MANUAL') {
    $checkTrigger = $conn->prepare('SELECT COUNT(*) as used FROM transiciones_estado WHERE modulo = ? AND trigger_code = ?');
    $checkTrigger->bind_param('ss', $modulo, $trigger_code);
    $checkTrigger->execute();
    $triggerRes = $checkTrigger->get_result()->fetch_assoc();
    $checkTrigger->close();

    if ($triggerRes && intval($triggerRes['used']) > 0) {
        http_response_code(400);
        echo json_encode([
            'success' => false, 
            'message' => "El disparador '$trigger_code' ya está asignado a otra transición en este módulo. Cada disparador automático debe ser único."
        ]);
        $conn->close();
        exit;
    }
}

// Insertar la transición con el módulo
$stmt = $conn->prepare('INSERT INTO transiciones_estado (estado_origen_id, estado_destino_id, modulo, nombre, trigger_code) VALUES (?, ?, ?, ?, ?)');

if (!$stmt) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error al preparar consulta de inserción: ' . $conn->error]);
    exit;
}

$stmt->bind_param('iisss', $origen, $destino, $modulo, $nombre, $trigger_code);

$ok = $stmt->execute();

if ($ok) {
    // Devolver éxito con el ID insertado
    echo json_encode(['success' => true, 'id' => $stmt->insert_id]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'No se pudo crear la transición']);
}

$stmt->close();
$conn->close();
?>