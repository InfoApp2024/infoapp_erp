<?php
// ✅ ACTIVAR DEBUG COMPLETO
error_reporting(E_ALL);
ini_set('display_errors', 1);
ini_set('log_errors', 1);
ini_set('error_log', '/tmp/php_errors.log');

header("Content-Type: application/json");

require_once '../login/auth_middleware.php';
$currentUser = requireAuth();

// ✅ LOG INICIAL
error_log("=== INICIO DEBUG ANULAR SERVICIO ===");

try {
    // ✅ VERIFICAR QUE LOS ARCHIVOS EXISTEN
    if (!file_exists('conexion.php')) {
        throw new Exception('Archivo conexion.php no encontrado');
    }
    
    require 'conexion.php';
    error_log("DEBUG: conexion.php cargado correctamente");
    
    // ✅ VERIFICAR CONEXIÓN A BD
    if (!isset($conn) || $conn->connect_error) {
        throw new Exception('Error de conexión a BD: ' . ($conn->connect_error ?? 'Conexión no definida'));
    }
    error_log("DEBUG: Conexión a BD establecida");
    
    // ✅ VERIFICAR WebSocketNotifier (OPCIONAL)
    if (file_exists('WebSocketNotifier.php')) {
        require 'WebSocketNotifier.php';
        error_log("DEBUG: WebSocketNotifier.php cargado");
    } else {
        error_log("WARNING: WebSocketNotifier.php no encontrado, continuando sin WebSocket");
    }

    // ✅ LEER Y VALIDAR INPUT
    $raw_input = file_get_contents('php://input');
    error_log("DEBUG: Raw input recibido: " . $raw_input);
    
    if (empty($raw_input)) {
        throw new Exception('No se recibieron datos POST');
    }
    
    $input = json_decode($raw_input, true);
    
    if (!$input || json_last_error() !== JSON_ERROR_NONE) {
        throw new Exception('Error decodificando JSON: ' . json_last_error_msg());
    }
    
    error_log("DEBUG: JSON decodificado: " . json_encode($input));
    
    // ✅ EXTRAER VARIABLES
    $servicio_id = $input['servicio_id'] ?? null;
    $estado_final_id = $input['estado_final_id'] ?? null;
    $razon = $input['razon'] ?? null;
    $usuario_id = $input['usuario_id'] ?? null;

    error_log("DEBUG: Variables extraídas - servicio_id: $servicio_id, estado_final_id: $estado_final_id, usuario_id: $usuario_id");

    // ✅ VALIDACIONES BÁSICAS
    if (!$usuario_id) {
        echo json_encode([
            'success' => false,
            'message' => 'Error: usuario_id es requerido para anular. Usuario no autenticado.',
            'debug' => 'usuario_id no proporcionado'
        ]);
        exit;
    }

    if (!$servicio_id) {
        throw new Exception('ID del servicio es requerido');
    }
    if (!$estado_final_id) {
        throw new Exception('Estado final es requerido');
    }
    if (!$razon) {
        throw new Exception('Razón de anulación es requerida');
    }

    // ✅ VALIDAR LONGITUD DE RAZÓN
    $razon_limpia = trim($razon);
    if (strlen($razon_limpia) < 40) {
        throw new Exception('La razón de anulación debe tener al menos 40 caracteres');
    }
    if (strlen($razon_limpia) > 500) {
        throw new Exception('La razón de anulación no puede exceder 500 caracteres');
    }

    error_log("DEBUG: Validaciones básicas pasadas");

    // ✅ VERIFICAR QUE EL SERVICIO EXISTE
    $stmt = $conn->prepare("SELECT estado, anular_servicio, o_servicio FROM servicios WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Error preparando consulta de verificación: ' . $conn->error);
    }
    
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $servicio = $result->fetch_assoc();
    $stmt->close();

    error_log("DEBUG: Servicio encontrado: " . json_encode($servicio));

    if (!$servicio) {
        throw new Exception('Servicio no encontrado con ID: ' . $servicio_id);
    }

    if ($servicio['anular_servicio'] == 1) {
        throw new Exception('El servicio #' . $servicio['o_servicio'] . ' ya está anulado');
    }

    // ✅ VERIFICAR ESTADO FINAL
    $stmt = $conn->prepare("SELECT nombre_estado FROM estados_proceso WHERE id = ?");
    if (!$stmt) {
        throw new Exception('Error preparando consulta de estado: ' . $conn->error);
    }
    
    $stmt->bind_param("i", $estado_final_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $estado_final = $result->fetch_assoc();
    $stmt->close();

    error_log("DEBUG: Estado final encontrado: " . json_encode($estado_final));

    if (!$estado_final) {
        throw new Exception('Estado final no válido con ID: ' . $estado_final_id);
    }

    // ✅ ACTUALIZAR SERVICIO
    $update_sql = "
        UPDATE servicios 
        SET estado = ?, 
            anular_servicio = 1, 
            razon = ?,
            fecha_finalizacion = NOW(),
            fecha_actualizacion = NOW(),
            usuario_ultima_actualizacion = ?
        WHERE id = ?
    ";
    
    error_log("DEBUG: SQL a ejecutar: " . $update_sql);
    error_log("DEBUG: Parámetros: estado_final_id=$estado_final_id, razon_limpia=$razon_limpia, usuario_id=$usuario_id, servicio_id=$servicio_id");
    
    $stmt = $conn->prepare($update_sql);
    if (!$stmt) {
        throw new Exception('Error preparando consulta de actualización: ' . $conn->error);
    }
    
    $stmt->bind_param("isii", $estado_final_id, $razon_limpia, $usuario_id, $servicio_id);

    if ($stmt->execute()) {
        $affected_rows = $stmt->affected_rows;
        $stmt->close();
        
        error_log("DEBUG: UPDATE exitoso, filas afectadas: " . $affected_rows);
        
        // ✅ RESPUESTA BÁSICA SIN WEBSOCKET (para debug)
        echo json_encode([
            'success' => true,
            'message' => 'Servicio anulado exitosamente y movido al estado final: ' . $estado_final['nombre_estado'],
            'debug' => [
                'servicio_id' => $servicio_id,
                'estado_final' => $estado_final['nombre_estado'],
                'razon_anulacion' => $razon_limpia,
                'usuario_anulacion' => $usuario_id,
                'affected_rows' => $affected_rows,
                'websocket_skipped' => true
            ]
        ]);
        
    } else {
        throw new Exception('Error al anular el servicio: ' . $stmt->error);
    }

} catch (Exception $e) {
    error_log("ERROR ANULAR SERVICIO: " . $e->getMessage());
    error_log("STACK TRACE: " . $e->getTraceAsString());
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage(),
        'debug' => [
            'error_line' => $e->getLine(),
            'error_file' => $e->getFile()
        ]
    ]);
}

// ✅ CERRAR CONEXIONES
if (isset($stmt)) $stmt->close();
if (isset($conn)) $conn->close();

error_log("=== FIN DEBUG ANULAR SERVICIO ===");
?>