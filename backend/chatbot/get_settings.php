<?php
// backend/chatbot/get_settings.php
require_once '../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php';
require_once './encryption_helper.php';

header('Content-Type: application/json');

// 1. Autenticación
try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

// 2. Obtener API Key de la BD
$sql = "SELECT setting_value FROM app_settings WHERE setting_key = 'gemini_api_key' ORDER BY id DESC LIMIT 1";
$result = $conn->query($sql);

$maskedKey = null;
$hasKey = false;

if ($result && $row = $result->fetch_assoc()) {
    $encrypted = $row['setting_value'];
    $decrypted = decryptData($encrypted);

    if (!empty($decrypted)) {
        $hasKey = true;
        $len = strlen($decrypted);
        if ($len > 8) {
            $maskedKey = '...' . substr($decrypted, -8);
        } else {
            $maskedKey = $decrypted;
        }
    }
}

// Si no hay en BD, verificar config (opcional, pero el usuario quiere ver lo que se está usando)
if (!$hasKey && defined('GEMINI_API_KEY') && !empty(GEMINI_API_KEY)) {
    $decrypted = GEMINI_API_KEY;
    $len = strlen($decrypted);
    if ($len > 8) {
        $maskedKey = '...' . substr($decrypted, -8) . ' (Config)';
    } else {
        $maskedKey = $decrypted;
    }
    $hasKey = true;
}

echo json_encode([
    'success' => true,
    'has_key' => $hasKey,
    'masked_key' => $maskedKey
]);
