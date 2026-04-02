<?php
// backend/chatbot/save_settings.php
require_once '../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php';
require_once './encryption_helper.php';

header('Content-Type: application/json');

// 1. Autenticación (Solo usuarios logueados pueden cambiar esto)
try {
    $currentUser = requireAuth();
    // TODO: Validar si el usuario es ADMIN si fuera necesario.
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

// 2. Obtener datos
$input = json_decode(file_get_contents('php://input'), true);
$apiKey = $input['api_key'] ?? '';

if (empty($apiKey)) {
    echo json_encode(['error' => 'La API Key es requerida']);
    exit;
}

// 3. Encriptar
$encryptedKey = encryptData($apiKey);
$keyName = 'gemini_api_key';

// 4. Guardar en BD (Upsert)
// Primero intentamos verificar si la tabla existe, si no, la creamos (Lazy Init)
$checkTable = "SHOW TABLES LIKE 'app_settings'";
$result = $conn->query($checkTable);
if ($result->num_rows == 0) {
    $createSql = "CREATE TABLE app_settings (
        id INT AUTO_INCREMENT PRIMARY KEY,
        setting_key VARCHAR(50) NOT NULL UNIQUE,
        setting_value TEXT NOT NULL,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
    )";
    $conn->query($createSql);
}

// Usamos INSERT ... ON DUPLICATE KEY UPDATE
$sql = "INSERT INTO app_settings (setting_key, setting_value) VALUES (?, ?) 
        ON DUPLICATE KEY UPDATE setting_value = VALUES(setting_value)";

$stmt = $conn->prepare($sql);
$stmt->bind_param("ss", $keyName, $encryptedKey);

if ($stmt->execute()) {
    echo json_encode(['success' => true, 'message' => 'API Key guardada exitosamente']);
} else {
    http_response_code(500);
    echo json_encode(['error' => 'Error al guardar en base de datos: ' . $conn->error]);
}
