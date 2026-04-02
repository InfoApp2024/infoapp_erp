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
$id = isset($input['id']) ? intval($input['id']) : 0;

// Validar ID
if ($id <= 0) {
    http_response_code(400);
    echo json_encode(['success' => false, 'message' => 'id inválido']);
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

// Primero obtener el módulo y el estado base del estado
$modStmt = $conn->prepare('SELECT nombre_estado, modulo, estado_base_codigo FROM estados_proceso WHERE id = ?');
$modStmt->bind_param('i', $id);
$modStmt->execute();
$modRes = $modStmt->get_result();
$row = $modRes->fetch_assoc();
$modStmt->close();

// Verificar si el estado existe
if (!$row) {
    http_response_code(404);
    echo json_encode(['success' => false, 'message' => 'Estado no encontrado']);
    $conn->close();
    exit;
}

$nombreState = $row['nombre_estado'];
$modulo = $row['modulo'];
$estadoBase = $row['estado_base_codigo'];

// ✅ MEJORA: Solo bloquear si es el ÚNICO estado de su tipo base en el módulo
// Si el usuario creó otro estado (ej: 'OTRO') con el mismo código base (ej: 'CANCELADO'),
// el sistema debe permitir borrar el extra/huérfano.
if (!empty($estadoBase)) {
    // Contar cuántos estados hay en este módulo con el mismo estado base
    $countStmt = $conn->prepare('SELECT COUNT(*) as total FROM estados_proceso WHERE modulo = ? AND estado_base_codigo = ?');
    $countStmt->bind_param('ss', $modulo, $estadoBase);
    $countStmt->execute();
    $countRes = $countStmt->get_result()->fetch_assoc();
    $countStmt->close();

    if ($countRes['total'] <= 1) {
        http_response_code(400);
        echo json_encode([
            'success' => false,
            'message' => "ERROR CRÍTICO: El estado '$nombreState' es el ÚNICO representante del estado base ($estadoBase) para el módulo '$modulo' y no puede ser eliminado. El sistema necesita al menos un estado de este tipo para funcionar correctamente."
        ]);
        $conn->close();
        exit;
    }
}

// ✅ NUEVO: Verificar integridad referencial (si el estado está en uso)
$tablas_uso = [
    'servicios' => ['col' => 'estado', 'label' => 'Servicios'],
    'equipos' => ['col' => 'estado_id', 'label' => 'Equipos'],
    'inspecciones' => ['col' => 'estado_id', 'label' => 'Inspecciones']
];

try {
    foreach ($tablas_uso as $tabla => $config) {
        $columna = $config['col'];
        $nombre_amigable = $config['label'];

        // Verificar si la tabla existe antes de consultar
        $checkTable = $conn->query("SHOW TABLES LIKE '$tabla'");
        if ($checkTable && $checkTable->num_rows > 0) {
            // Verificar si la columna existe en esa tabla
            $checkCol = $conn->query("SHOW COLUMNS FROM $tabla LIKE '$columna'");
            if ($checkCol && $checkCol->num_rows > 0) {
                $sql_uso = "SELECT COUNT(*) as cuenta FROM $tabla WHERE $columna = ?";
                $stmt_uso = $conn->prepare($sql_uso);
                if ($stmt_uso) {
                    $stmt_uso->bind_param('i', $id);
                    $stmt_uso->execute();
                    $res_uso = $stmt_uso->get_result()->fetch_assoc();
                    $stmt_uso->close();

                    if ($res_uso['cuenta'] > 0) {
                        http_response_code(400);
                        echo json_encode([
                            'success' => false,
                            'message' => "No se puede eliminar: El estado está siendo utilizado en {$res_uso['cuenta']} registro(s) de $nombre_amigable."
                        ]);
                        $conn->close();
                        exit;
                    }
                }
            }
        }
    }
} catch (Exception $valEx) {
    // Si hay error en la validación (ej: tabla/columna no existe), ignoramos para no bloquear el borrado si la DB está incompleta
    // o registramos el error silenciosamente
}

// ✅ NUEVO: Verificar si el estado tiene transiciones vinculadas
// El usuario debe eliminarlas manualmente primero para evitar "estados huérfanos" desconectados.
$transStmt = $conn->prepare('SELECT COUNT(*) as total FROM transiciones_estado WHERE modulo = ? AND (estado_origen_id = ? OR estado_destino_id = ?)');
$transStmt->bind_param('sii', $modulo, $id, $id);
$transStmt->execute();
$transRes = $transStmt->get_result()->fetch_assoc();
$transStmt->close();

if ($transRes['total'] > 0) {
    http_response_code(400);
    echo json_encode([
        'success' => false,
        'message' => "Este estado está vinculado a {$transRes['total']} transición(es). Debe primero eliminar las transiciones desde el panel de transiciones antes de eliminar el estado."
    ]);
    $conn->close();
    exit;
}

// Ahora borrar el estado
$delE = $conn->prepare('DELETE FROM estados_proceso WHERE id = ?');
$delE->bind_param('i', $id);
$ok = $delE->execute();
$delE->close();

if ($ok) {
    echo json_encode(['success' => true]);
} else {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => 'No se pudo eliminar el estado']);
}

$conn->close();
?>