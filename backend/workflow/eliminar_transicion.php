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

// Obtener info de la transición para validar integridad
$stmt = $conn->prepare('SELECT estado_origen_id, estado_destino_id, modulo FROM transiciones_estado WHERE id = ?');
$stmt->bind_param('i', $id);
$stmt->execute();
$res = $stmt->get_result()->fetch_assoc();
$stmt->close();

if (!$res) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Transición no encontrada']);
    $conn->close();
    exit;
}

$origId = $res['estado_origen_id'];
$destId = $res['estado_destino_id'];
$modulo = $res['modulo'];

// ✅ NUEVO: Bloquear eliminación si el estado de origen o destino están en uso por servicios
// Esto protege que un servicio se quede sin opciones de movimiento o "atrapado" 
// si se borra el camino lógico.
if ($modulo === 'servicio') {
    $checkSql = 'SELECT COUNT(*) as total FROM servicios WHERE estado = ? OR estado = ?';
    $checkStmt = $conn->prepare($checkSql);
    if ($checkStmt) {
        $checkStmt->bind_param('ii', $origId, $destId);
        $checkStmt->execute();
        $useRes = $checkStmt->get_result()->fetch_assoc();
        $checkStmt->close();

        if ($useRes['total'] > 0) {
            http_response_code(400);
            echo json_encode([
                'success' => false,
                'message' => "No se puede eliminar la transición porque sus estados están siendo utilizados actualmente por {$useRes['total']} servicio(s). Primero debe mover los servicios a otros estados."
            ]);
            $conn->close();
            exit;
        }
    }
}

// Eliminar la transición
$stmt = $conn->prepare('DELETE FROM transiciones_estado WHERE id = ?');
$stmt->bind_param('i', $id);
$ok = $stmt->execute();

if ($ok) {
    echo json_encode(['success' => true, 'message' => 'Transición procesada correctamente']);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'Error al ejecutar la eliminación']);
}

$stmt->close();
$conn->close();
?>