<?php
// request_password_reset.php - ✅ VERSIÓN MEJORADA Y SEGURA
header("Access-Control-Allow-Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? '*'));
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit(0);
}

include '../conexion.php';

// ✅ CONFIGURACIÓN
const APP_BASE_URL = 'https://migracion-infoapp.novatechdevelopment.com/'; // ⚠️ Cambiar por tu URL real
const MAIL_FROM = 'notificaciones@novatechdevelopment.com';
const MAIL_FROM_NAME = 'InfoApp';

try {
    // ✅ OBTENER DATOS DE LA SOLICITUD
    $input = json_decode(file_get_contents('php://input'), true);

    if (!$input) {
        throw new Exception('Datos de solicitud no válidos');
    }

    $usuario = trim($input['usuario'] ?? '');
    $email = trim($input['email'] ?? '');

    // ✅ VALIDACIONES BÁSICAS
    if (empty($usuario) || empty($email)) {
        throw new Exception('Usuario y email son requeridos');
    }

    if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
        throw new Exception('Formato de email no válido');
    }

    // ✅ VERIFICAR USUARIO Y EMAIL
    $stmt = $conn->prepare("SELECT id, NOMBRE_USER, CORREO, ESTADO_USER FROM usuarios WHERE NOMBRE_USER = ? LIMIT 1");
    $stmt->bind_param("s", $usuario);
    $stmt->execute();
    $result = $stmt->get_result();

    // 🔒 MENSAJE GENÉRICO (siempre el mismo para prevenir enumeración)
    $genericMessage = 'Si los datos coinciden, te enviamos un correo con instrucciones.';

    if ($result->num_rows === 0) {
        // Usuario no existe, pero respondemos genérico
        echo json_encode([
            'success' => true,
            'message' => $genericMessage
        ]);
        exit;
    }

    $user = $result->fetch_assoc();

    // Verificar que el email coincida (case-insensitive)
    if (strcasecmp($user['CORREO'], $email) !== 0) {
        // Email no coincide, pero respondemos genérico
        echo json_encode([
            'success' => true,
            'message' => $genericMessage
        ]);
        exit;
    }

    // ✅ VERIFICAR ESTADO DEL USUARIO
    if ($user['ESTADO_USER'] !== 'activo') {
        throw new Exception('Usuario inactivo. Contacta al administrador');
    }

    // ✅ RATE LIMITING - Prevenir spam
    $ipAddress = $_SERVER['REMOTE_ADDR'] ?? 'unknown';
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM password_reset_tokens 
        WHERE ip_address = ? 
        AND created_at > DATE_SUB(NOW(), INTERVAL 1 HOUR)
    ");
    $stmt->bind_param("s", $ipAddress);
    $stmt->execute();
    $limitResult = $stmt->get_result();
    $limitData = $limitResult->fetch_assoc();

    if ($limitData['count'] >= 5) {
        throw new Exception('Demasiadas solicitudes. Intenta en 1 hora');
    }

    // ✅ GENERAR CÓDIGO SEGURO (8 caracteres hexadecimales en mayúsculas)
    $code = strtoupper(bin2hex(random_bytes(4))); // Genera: A3F8B2C1
    $expiresAt = date('Y-m-d H:i:s', strtotime('+15 minutes'));
    $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;

    // 🔒 HASHEAR EL CÓDIGO ANTES DE GUARDARLO (IMPORTANTE)
    $hashedCode = password_hash($code, PASSWORD_DEFAULT);

    // ✅ GUARDAR TOKEN EN BASE DE DATOS
    $stmt = $conn->prepare("
        INSERT INTO password_reset_tokens 
        (usuario_id, usuario_nombre, email, token, expires_at, is_used, ip_address, user_agent) 
        VALUES (?, ?, ?, ?, ?, 0, ?, ?)
    ");
    $stmt->bind_param(
        "issssss",
        $user['id'],
        $user['NOMBRE_USER'],
        $user['CORREO'],
        $hashedCode,  // 🔒 Guardamos el hash, NO el código original
        $expiresAt,
        $ipAddress,
        $userAgent
    );

    if (!$stmt->execute()) {
        error_log("Error insertando token: " . $stmt->error);
        throw new Exception('Error al generar código de recuperación');
    }

    // ✅ ENVIAR EMAIL CON EL CÓDIGO
    // URL para Flutter Web (sin hash #)
    $resetUrl = APP_BASE_URL . '?usuario=' . urlencode($usuario) . '&code=' . urlencode($code);
    $emailSent = sendRecoveryEmail($user['CORREO'], $user['NOMBRE_USER'], $code, $resetUrl);

    // ✅ RESPUESTA EXITOSA (NUNCA mostrar el código aquí por seguridad)
    echo json_encode([
        'success' => true,
        'message' => $genericMessage,
        'email_sent' => $emailSent
    ]);

} catch (Exception $e) {
    error_log("ERROR en recuperación: " . $e->getMessage());

    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();

// ✅ FUNCIÓN PARA ENVIAR EMAIL
function sendRecoveryEmail($email, $usuario, $code, $resetUrl)
{
    $subject = 'Restablece tu contraseña - InfoApp';

    $html = '<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
</head>
<body style="font-family: Arial, sans-serif; color:#333; line-height: 1.6; max-width: 600px; margin: 0 auto;">
    <div style="background: linear-gradient(135deg, #6C63FF 0%, #5A52D5 100%); padding: 20px; text-align: center;">
        <h1 style="color: white; margin: 0;">🔐 Recuperación de Contraseña</h1>
    </div>
    <div style="padding: 30px; background: #f9f9f9;">
        <h2 style="color: #333;">Hola, ' . htmlspecialchars($usuario) . '</h2>
        <p>Recibimos una solicitud para restablecer tu contraseña. Si fuiste tú, haz clic en el botón:</p>
        <div style="text-align: center; margin: 30px 0;">
            <a href="' . htmlspecialchars($resetUrl) . '" 
               style="background:#6C63FF; color:#fff; padding:15px 30px; text-decoration:none; border-radius:8px; display:inline-block; font-weight: bold;">
               Restablecer Contraseña
            </a>
        </div>
        <div style="background: white; padding: 15px; border-left: 4px solid #6C63FF; margin: 20px 0;">
            <p style="margin: 0;"><strong>Código de verificación:</strong></p>
            <p style="font-size: 24px; font-weight: bold; color: #6C63FF; margin: 10px 0; letter-spacing: 2px;">' . htmlspecialchars($code) . '</p>
            <p style="margin: 0; font-size: 12px; color: #666;">Este código expira en 15 minutos</p>
        </div>
        <p style="color: #666; font-size: 14px;">Si no solicitaste este cambio, ignora este correo.</p>
    </div>
    <div style="background: #333; color: white; padding: 20px; text-align: center; font-size: 12px;">
        <p style="margin: 0;">© 2025 InfoApp - Todos los derechos reservados</p>
    </div>
</body>
</html>';

    $headers = [];
    $headers[] = 'MIME-Version: 1.0';
    $headers[] = 'Content-type: text/html; charset=UTF-8';
    $headers[] = 'From: ' . MAIL_FROM_NAME . ' <' . MAIL_FROM . '>';
    $headers[] = 'Reply-To: ' . MAIL_FROM;

    return mail($email, '=?UTF-8?B?' . base64_encode($subject) . '?=', $html, implode("\r\n", $headers));
}
?>