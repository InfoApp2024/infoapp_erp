<?php
// reset_password.php - ✅ VERSIÓN SEGURA CON HASH
header("Access-Control-Allow-Origin: " . ($_SERVER['HTTP_ORIGIN'] ?? '*'));
header("Access-Control-Allow-Methods: POST, OPTIONS");
header("Access-Control-Allow-Headers: Content-Type");
header("Content-Type: application/json");

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    header("HTTP/1.1 200 OK");
    exit(0);
}

include '../conexion.php';

try {
    // ✅ OBTENER DATOS DE LA SOLICITUD
    $input = json_decode(file_get_contents('php://input'), true);
    
    if (!$input) {
        throw new Exception('Datos de solicitud no válidos');
    }
    
    $usuario = trim($input['usuario'] ?? '');
    $code = trim($input['code'] ?? ''); // Código ingresado por el usuario
    $newPassword = trim($input['nueva_password'] ?? $input['new_password'] ?? '');
    
    // ✅ VALIDACIONES BÁSICAS
    if (empty($usuario) || empty($code) || empty($newPassword)) {
        throw new Exception('Todos los campos son requeridos');
    }
    
    if (strlen($newPassword) < 8) {
        throw new Exception('La nueva contraseña debe tener al menos 8 caracteres');
    }
    
    if (strlen($code) !== 8) {
        throw new Exception('Código de recuperación no válido');
    }
    
    // 🔒 BUSCAR TOKENS VÁLIDOS DEL USUARIO
    $stmt = $conn->prepare("
        SELECT 
            id, usuario_id, token, expires_at, is_used, created_at
        FROM password_reset_tokens 
        WHERE usuario_nombre = ? 
        AND is_used = 0 
        AND expires_at > NOW()
        ORDER BY created_at DESC
        LIMIT 5
    ");
    $stmt->bind_param("s", $usuario);
    $stmt->execute();
    $result = $stmt->get_result();
    
    if ($result->num_rows === 0) {
        throw new Exception('Código de recuperación no válido o expirado');
    }
    
    // 🔒 VERIFICAR EL CÓDIGO CONTRA TODOS LOS TOKENS VÁLIDOS
    $validToken = null;
    while ($tokenData = $result->fetch_assoc()) {
        // Verificar si el código ingresado coincide con el hash guardado
        if (password_verify($code, $tokenData['token'])) {
            $validToken = $tokenData;
            break;
        }
    }
    
    if (!$validToken) {
        throw new Exception('Código de recuperación incorrecto');
    }
    
    // ✅ VERIFICAR QUE EL USUARIO EXISTE Y ESTÁ ACTIVO
    $stmt = $conn->prepare("SELECT id, NOMBRE_USER, ESTADO_USER FROM usuarios WHERE id = ?");
    $stmt->bind_param("i", $validToken['usuario_id']);
    $stmt->execute();
    $userResult = $stmt->get_result();
    
    if ($userResult->num_rows === 0) {
        throw new Exception('Usuario no encontrado');
    }
    
    $user = $userResult->fetch_assoc();
    
    if ($user['ESTADO_USER'] !== 'activo') {
        throw new Exception('Usuario inactivo. Contacta al administrador');
    }
    
    // ✅ CIFRAR NUEVA CONTRASEÑA
    $hashedPassword = password_hash($newPassword, PASSWORD_DEFAULT);
    
    // ✅ INICIAR TRANSACCIÓN
    $conn->begin_transaction();
    
    try {
        // ✅ ACTUALIZAR CONTRASEÑA DEL USUARIO
        $stmt = $conn->prepare("
            UPDATE usuarios 
            SET CONTRASEÑA = ? 
            WHERE id = ?
        ");
        $stmt->bind_param("si", $hashedPassword, $user['id']);
        
        if (!$stmt->execute()) {
            throw new Exception('Error al actualizar la contraseña');
        }
        
        if ($stmt->affected_rows === 0) {
            throw new Exception('No se pudo actualizar la contraseña');
        }
        
        // ✅ MARCAR TOKEN COMO USADO
        $stmt = $conn->prepare("
            UPDATE password_reset_tokens 
            SET is_used = 1, used_at = NOW() 
            WHERE id = ?
        ");
        $stmt->bind_param("i", $validToken['id']);
        
        if (!$stmt->execute()) {
            throw new Exception('Error al procesar token');
        }
        
        // ✅ INVALIDAR TODOS LOS OTROS TOKENS DEL USUARIO (seguridad)
        $stmt = $conn->prepare("
            UPDATE password_reset_tokens 
            SET is_used = 1, used_at = NOW() 
            WHERE usuario_id = ? AND is_used = 0 AND id != ?
        ");
        $stmt->bind_param("ii", $user['id'], $validToken['id']);
        $stmt->execute();
        
        // ✅ COMMIT TRANSACCIÓN
        $conn->commit();
        
        // ✅ LOG DE SEGURIDAD (importante para auditoría)
        error_log("Password reset successful for user: " . $user['NOMBRE_USER'] . " at " . date('Y-m-d H:i:s'));
        
        // ✅ RESPUESTA EXITOSA
        echo json_encode([
            'success' => true,
            'message' => 'Contraseña actualizada exitosamente. Ya puedes iniciar sesión con tu nueva contraseña.',
            'user' => $user['NOMBRE_USER']
        ]);
        
    } catch (Exception $e) {
        // ✅ ROLLBACK EN CASO DE ERROR
        $conn->rollback();
        throw $e;
    }
    
} catch (Exception $e) {
    error_log("ERROR en reset de contraseña: " . $e->getMessage());
    
    echo json_encode([
        'success' => false,
        'message' => $e->getMessage()
    ]);
}

$conn->close();
?>