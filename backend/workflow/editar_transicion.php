<?php
// Configuración de cabeceras CORS
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
$id = isset($input['id']) ? intval($input['id']) : 0;
$nombre = isset($input['nombre']) ? trim($input['nombre']) : null;
$triggerCode = isset($input['trigger_code']) ? trim($input['trigger_code']) : null;

// Validar ID
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'ID inválido']);
    exit;
}

// Conexión
require '../conexion.php';

// Verificar conexión
if ($conn->connect_errno) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error de conexión a la base de datos']);
    exit;
}

// Configurar charset
$conn->set_charset('utf8mb4');

// ✅ VALIDACIÓN DE TRIGGER ÚNICO (Si se está cambiando y no es MANUAL)
if ($triggerCode !== null && $triggerCode !== 'MANUAL') {
    // Necesitamos el módulo de la transición actual
    $modQuery = $conn->prepare("SELECT modulo FROM transiciones_estado WHERE id = ?");
    $modQuery->bind_param("i", $id);
    $modQuery->execute();
    $modRes = $modQuery->get_result()->fetch_assoc();
    $modQuery->close();

    if ($modRes) {
        $modulo = $modRes['modulo'];
        $checkTrigger = $conn->prepare("SELECT COUNT(*) as used FROM transiciones_estado WHERE modulo = ? AND trigger_code = ? AND id != ?");
        $checkTrigger->bind_param("ssi", $modulo, $triggerCode, $id);
        $checkTrigger->execute();
        $triggerRes = $checkTrigger->get_result()->fetch_assoc();
        $checkTrigger->close();

        if ($triggerRes && intval($triggerRes['used']) > 0) {
            http_response_code(400);
            echo json_encode([
                'success' => false, 
                'message' => "El disparador '$triggerCode' ya está asignado a otra transición. Cada disparador automático debe ser único por módulo."
            ]);
            $conn->close();
            exit;
        }
    }
}

// Actualizar la transición
$sql = "UPDATE transiciones_estado SET ";
$params = [];
$types = "";

if ($nombre !== null) {
    $sql .= "nombre = ?, ";
    $params[] = $nombre;
    $types .= "s";
}

if ($triggerCode !== null) {
    $sql .= "trigger_code = ?, ";
    $params[] = $triggerCode;
    $types .= "s";
}

// Quitar la última coma y espacio
$sql = rtrim($sql, ", ");
$sql .= " WHERE id = ?";
$params[] = $id;
$types .= "i";

$stmt = $conn->prepare($sql);

if ($stmt === false) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error preparando consulta: ' . $conn->error]);
    exit;
}

$stmt->bind_param($types, ...$params);
$ok = $stmt->execute();

if ($ok) {
    echo json_encode(['success' => true, 'message' => 'Transición actualizada correctamente']);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error al ejecutar la actualización: ' . $stmt->error]);
}

$stmt->close();
$conn->close();
?>