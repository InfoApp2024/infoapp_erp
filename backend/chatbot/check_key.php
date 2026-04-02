<?php
// backend/chatbot/check_key.php
require_once __DIR__ . '/../conexion.php';
require_once './encryption_helper.php';

header('Content-Type: application/json');

$sql = "SELECT setting_value FROM app_settings WHERE setting_key = 'gemini_api_key' LIMIT 1";
$result = $conn->query($sql);

$response = [
    'has_db_key' => false,
    'decrypted_preview' => null,
    'error' => null
];

if ($result && $row = $result->fetch_assoc()) {
    $response['has_db_key'] = true;
    $encrypted = $row['setting_value'];
    try {
        $decrypted = decryptData($encrypted);
        if (!empty($decrypted)) {
            $response['decrypted_preview'] = substr($decrypted, 0, 4) . '...' . substr($decrypted, -4);
            $response['length'] = strlen($decrypted);
        } else {
            $response['error'] = 'Decryption returned empty';
        }
    } catch (Exception $e) {
        $response['error'] = 'Decryption failed: ' . $e->getMessage();
    }
} else {
    $response['error'] = 'No key found in database';
}

echo json_encode($response);
