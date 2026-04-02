<?php
require_once __DIR__ . '/auth_middleware.php';

// ✅ Establecer headers CORS de forma estandarizada
setCORSHeaders();

// ✅ Manejo de preflight
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit();
}

session_start();

// Logs de depuración
$debugLog = [];

$debugLog[] = "Script iniciado en /login/logout.php";
$debugLog[] = "Método recibido: " . $_SERVER['REQUEST_METHOD'];

require '../conexion.php';
require '../conexion_admin.php';

// ✅ Solo permitir POST
if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode([
        "success" => false,
        "message" => "Método no permitido",
        "debug"   => $debugLog
    ]);
    exit;
}

try {
    // ✅ Leer input JSON
    $input = json_decode(file_get_contents('php://input'), true);
    $debugLog[] = "Input recibido: " . json_encode($input);

    $usuarioNombre = $input['NOMBRE_USER'] 
        ?? $input['usuario'] 
        ?? ($_SESSION['usuario_nombre'] ?? null);
    $usuarioId = $_SESSION['usuario_id'] ?? null;

    $debugLog[] = "Usuario detectado: " . ($usuarioNombre ?: "null");
    $debugLog[] = "UsuarioID en sesión: " . ($usuarioId ?: "null");

    if (!$usuarioNombre) {
        echo json_encode([
            "success" => false,
            "message" => "Usuario requerido para logout",
            "debug"   => $debugLog
        ]);
        exit();
    }

    // (Opcional) Guardar log en BD
    if ($conn && $usuarioId) {
        $stmt = $conn->prepare(
            "INSERT INTO logs_sesion (usuario_id, accion, fecha) VALUES (?, 'logout', NOW())"
        );
        if ($stmt) {
            $stmt->bind_param("i", $usuarioId);
            $stmt->execute();
            $stmt->close();
            $debugLog[] = "Logout registrado en logs_sesion";
        } else {
            $debugLog[] = "No se pudo preparar statement para logs_sesion";
        }
    } else {
        $debugLog[] = "Conexión o usuarioId no disponibles para registrar log";
    }

    // ✅ Destruir la sesión
    session_unset();
    session_destroy();
    $debugLog[] = "Sesión destruida correctamente";

    echo json_encode([
        "success" => true,
        "message" => "Logout exitoso",
        "usuario" => $usuarioNombre,
        "timestamp" => date("Y-m-d H:i:s"),
        "debug"   => $debugLog
    ]);
    exit();

} catch (Exception $e) {
    $debugLog[] = "Excepción: " . $e->getMessage();
    echo json_encode([
        "success" => false,
        "message" => "Error en el logout: " . $e->getMessage(),
        "debug"   => $debugLog
    ]);
    exit();
}
