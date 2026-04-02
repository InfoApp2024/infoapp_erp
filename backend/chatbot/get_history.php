<?php
// backend/chatbot/get_history.php
require_once '../login/auth_middleware.php';
require_once __DIR__ . '/../conexion.php';

header('Content-Type: application/json');

// 1. Autenticación
try {
    $currentUser = requireAuth();
} catch (Exception $e) {
    http_response_code(401);
    echo json_encode(['error' => 'No autorizado']);
    exit;
}

// 2. Obtener historial
$userId = $currentUser['id'];

// Asegurar que la tabla existe (por si es la primera vez que se consulta antes de chatear)
$conn->query("CREATE TABLE IF NOT EXISTS chat_messages (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    message TEXT NOT NULL,
    is_user BOOLEAN DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)");

$sql = "SELECT message, is_user, created_at FROM chat_messages WHERE user_id = ? ORDER BY created_at ASC";
$stmt = $conn->prepare($sql);
$stmt->bind_param("i", $userId);
$stmt->execute();
$result = $stmt->get_result();

$messages = [];
while ($row = $result->fetch_assoc()) {
    $messages[] = [
        'text' => $row['message'],
        'isUser' => (bool)$row['is_user'],
        'timestamp' => $row['created_at']
    ];
}

echo json_encode(['success' => true, 'messages' => $messages]);
?>
