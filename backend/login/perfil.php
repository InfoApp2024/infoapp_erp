<?php
// perfil.php
// Endpoint para obtener datos frescos del usuario autenticado

require_once '../conexion.php';
require_once 'auth_middleware.php';

// Validar token y obtener datos básicos
$userData = requireAuth();
$userId = $userData['id'];

try {
    // Consultar datos completos y actualizados del usuario (usando nombres reales de columnas)
    $sql = "SELECT u.id, u.NOMBRE_USER, u.TIPO_ROL, u.NOMBRE_CLIENTE, u.CORREO, u.NIT, 
                   u.funcionario_id, u.es_auditor, u.can_edit_closed_ops, u.ESTADO_USER
            FROM usuarios u 
            WHERE u.id = ? AND u.ESTADO_USER = 'activo'
            LIMIT 1";

    $stmt = $conn->prepare($sql);
    if (!$stmt) {
        throw new Exception("Error preparando consulta: " . $conn->error);
    }

    $stmt->bind_param("i", $userId);
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        throw new Exception("Usuario no encontrado o inactivo");
    }

    $user = $result->fetch_assoc();

    // Extraer es_auditor de forma insensible al casing de la DB
    $esAuditor = 0;
    foreach ($user as $key => $val) {
        if (strtoupper($key) === 'ES_AUDITOR') {
            $esAuditor = (int) $val;
            break;
        }
    }
    
    $canEditClosedOps = 0;
    foreach ($user as $key => $val) {
        if (strtoupper($key) === 'CAN_EDIT_CLOSED_OPS') {
            $canEditClosedOps = (int) $val;
            break;
        }
    }

    // Formatear respuesta consistente con login.php
    $response = [
        'success' => true,
        'data' => [
            'id' => (int) $user['id'],
            'usuario' => $user['NOMBRE_USER'],
            'rol' => $user['TIPO_ROL'],
            'nombre_completo' => $user['NOMBRE_CLIENTE'],
            'correo' => $user['CORREO'],
            'nit' => $user['NIT'],
            'es_auditor' => $esAuditor,
            'can_edit_closed_ops' => $canEditClosedOps,
            'estado' => $user['ESTADO_USER'],
            'funcionario_id' => $user['funcionario_id'] ? (int) $user['funcionario_id'] : null
        ]
    ];

    sendJsonResponse($response);

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'error' => 'Error de Perfil',
        'message' => $e->getMessage(),
        'code' => 500
    ], 500);
}
