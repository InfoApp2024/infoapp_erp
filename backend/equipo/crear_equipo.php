<?php
// crear_equipo.php - Protegido con JWT

// CRÍTICO: Desactivar TODO output de errores/warnings
error_reporting(0);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

// Buffer de output para capturar cualquier warning
ob_start();

define('DEBUG_LOG', __DIR__ . '/debug_crear_equipo.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    file_put_contents(DEBUG_LOG, "[$time] $msg\n", FILE_APPEND);
}

log_debug("========================================");
log_debug("🆕 NUEVA REQUEST - CREAR EQUIPO");
log_debug("========================================");

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    log_debug("👤 Usuario autenticado: " . $currentUser['usuario']);

    if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
        ob_clean();
        sendJsonResponse(['success' => false, 'message' => 'Método no permitido'], 405);
    }

    require '../conexion.php';

    $raw_input = file_get_contents('php://input');
    log_debug("📥 Input recibido: " . $raw_input);

    $input = json_decode($raw_input, true);

    if (json_last_error() !== JSON_ERROR_NONE) {
        ob_clean();
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }

    // Extraer campos
    $nombre = isset($input['nombre']) ? trim($input['nombre']) : null;
    $modelo = isset($input['modelo']) ? trim($input['modelo']) : null;
    $marca = isset($input['marca']) ? trim($input['marca']) : null;
    $placa = isset($input['placa']) ? trim($input['placa']) : null;
    $codigo = isset($input['codigo']) ? trim($input['codigo']) : null;
    $ciudad = isset($input['ciudad']) ? trim($input['ciudad']) : null;
    $planta = isset($input['planta']) ? trim($input['planta']) : null;
    $linea_prod = isset($input['linea_prod']) ? trim($input['linea_prod']) : null;
    $nombre_empresa = isset($input['nombre_empresa']) ? trim($input['nombre_empresa']) : null;
    $cliente_id = isset($input['cliente_id']) ? intval($input['cliente_id']) : null;
    $estado_id = isset($input['estado_id']) ? intval($input['estado_id']) : null;
    $usuario_nombre = $currentUser['usuario'];

    // Validar campos requeridos
    if (empty($nombre) || empty($placa) || empty($nombre_empresa)) {
        ob_clean();
        throw new Exception('Campos obligatorios: nombre, placa y nombre_empresa');
    }

    log_debug("✅ Validación OK - Nombre: $nombre, Placa: $placa");
    
    // 🛡️ REGLA CRÍTICA: No permitir creación si el módulo no tiene estados configurados
    $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM estados_proceso WHERE modulo = 'equipo'");
    $stmt->execute();
    $resStates = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($resStates['count'] == 0) {
        ob_clean();
        // Respond with a specific message that the frontend can use
        sendJsonResponse([
            'success' => false, 
            'message' => 'No se puede crear el equipo: No hay estados configurados para el módulo de equipos. Por favor, configure el flujo de estados primero.',
            'error_code' => 'MODULE_NO_STATES'
        ], 400); 
    }

    // 🔍 Validar que el estado_id exista en la tabla estados_proceso
    if (!empty($estado_id)) {
        $stmt = $conn->prepare("SELECT COUNT(*) AS count FROM estados_proceso WHERE id = ?");
        $stmt->bind_param("i", $estado_id);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($res['count'] == 0) {
            ob_clean();
            throw new Exception("El estado_id ($estado_id) no existe en la tabla estados_proceso");
        }
        log_debug("✅ estado_id $estado_id validado correctamente");
    } else {
        log_debug("⚠️ estado_id no proporcionado, asignando NULL");
        $estado_id = null;
    }

    // Verificar duplicados por placa y empresa
    $stmt = $conn->prepare("SELECT COUNT(*) as count FROM equipos WHERE placa = ? AND nombre_empresa = ? AND activo = 1");
    $stmt->bind_param("ss", $placa, $nombre_empresa);
    $stmt->execute();
    $row = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if ($row['count'] > 0) {
        ob_clean();
        // Mensaje específico que el frontend puede detectar
        sendJsonResponse(['success' => false, 'message' => 'Ya existe un equipo con esta placa para esta empresa', 'error_code' => 'DUPLICATE_PLACA'], 409);
    }

    // Verificar duplicados por código y empresa (si el código no es vacío)
    if (!empty($codigo)) {
        $stmt = $conn->prepare("SELECT COUNT(*) as count FROM equipos WHERE codigo = ? AND nombre_empresa = ? AND activo = 1");
        $stmt->bind_param("ss", $codigo, $nombre_empresa);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ($row['count'] > 0) {
            ob_clean();
            sendJsonResponse(['success' => false, 'message' => 'Ya existe un equipo con este código para esta empresa', 'error_code' => 'DUPLICATE_CODIGO'], 409);
        }
    }

    // INSERT con estado_id validado
    $sql = "INSERT INTO equipos (
                nombre, modelo, marca, placa, codigo, ciudad, 
                planta, linea_prod, nombre_empresa, cliente_id, usuario_registro, activo, estado_id
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?)";

    $stmt = $conn->prepare($sql);

    $modelo = $modelo ?: null;
    $marca = $marca ?: null;
    $codigo = $codigo ?: null;
    $ciudad = $ciudad ?: null;
    $planta = $planta ?: null;
    $linea_prod = $linea_prod ?: null;

    $stmt->bind_param(
        "sssssssssisi",
        $nombre,
        $modelo,
        $marca,
        $placa,
        $codigo,
        $ciudad,
        $planta,
        $linea_prod,
        $nombre_empresa,
        $cliente_id,
        $usuario_nombre,
        $estado_id
    );

    if ($stmt->execute()) {
        $equipo_id = $conn->insert_id;

        log_debug("✅ Equipo creado con ID: $equipo_id");

        $response = [
            'success' => true,
            'message' => 'Equipo creado exitosamente',
            'id' => $equipo_id,
            'equipo_id' => $equipo_id,
            'usuario_registro' => $usuario_nombre,
            'estado_id' => $estado_id,
            'data' => [
                'id' => $equipo_id,
                'nombre' => $nombre,
                'modelo' => $modelo,
                'marca' => $marca,
                'placa' => $placa,
                'codigo' => $codigo,
                'ciudad' => $ciudad,
                'planta' => $planta,
                'linea_prod' => $linea_prod,
                'nombre_empresa' => $nombre_empresa,
                'cliente_id' => $cliente_id,
                'usuario_registro' => $usuario_nombre,
                'activo' => true,
                'estado_id' => $estado_id
            ]
        ];

        ob_clean();
        http_response_code(201);
        header('Content-Type: application/json');
        echo json_encode($response);
        exit();
    } else {
        ob_clean();
        throw new Exception('Error al crear equipo: ' . $stmt->error);
    }

} catch (Exception $e) {
    log_debug("❌ ERROR: " . $e->getMessage());
    ob_clean();
    http_response_code(500);
    header('Content-Type: application/json');
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
    exit();

} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
    ob_end_clean();
}
?>