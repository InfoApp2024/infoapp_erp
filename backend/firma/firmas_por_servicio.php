<?php
// firmas_por_servicio.php - Protegido con JWT
// FINAL: Staff de usuarios, Funcionario de funcionario

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_firmas_por_servicio.txt');

function log_debug($msg) {
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function() {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("ERROR FATAL: " . $error['message']);
        log_debug("Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function($e) {
    log_debug("EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("NUEVA REQUEST FIRMAS POR SERVICIO");
log_debug("========================================");
log_debug("IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("auth_middleware cargado");
    
    $currentUser = requireAuth();
    log_debug("Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");
    
    logAccess($currentUser, '/firma/firmas_por_servicio.php', 'get_firmas_by_service');
    log_debug("Acceso registrado");
    
    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }
    
    log_debug("Requiriendo conexión...");
    require '../conexion.php';
    log_debug("conexion.php cargado");

    // Obtener ID del servicio
    $id_servicio = isset($_GET['id_servicio']) ? intval($_GET['id_servicio']) : null;

    if (!$id_servicio) {
        log_debug("ID de servicio no proporcionado");
        sendJsonResponse(errorResponse('ID de servicio requerido'), 400);
    }

    log_debug("Buscando firmas para servicio ID: $id_servicio");

    // Primero verificar que el servicio existe
    $stmt_servicio = $conn->prepare("SELECT id, o_servicio FROM servicios WHERE id = ?");
    if (!$stmt_servicio) {
        log_debug("ERROR PREPARE servicio: " . $conn->error);
        throw new Exception('Error prepare servicio: ' . $conn->error);
    }
    $stmt_servicio->bind_param("i", $id_servicio);
    $stmt_servicio->execute();
    $result_servicio = $stmt_servicio->get_result();
    $servicio = $result_servicio->fetch_assoc();

    if (!$servicio) {
        log_debug("Servicio no encontrado con ID: $id_servicio");
        sendJsonResponse(errorResponse('Servicio no encontrado'), 404);
    }
    log_debug("Servicio encontrado - o_servicio: " . $servicio['o_servicio']);

    // Query para obtener todas las firmas de este servicio
    // FINAL: Staff de usuarios, Funcionario de funcionario
    $sql = "SELECT 
                f.id,
                f.id_servicio,
                f.id_staff_entrega,
                f.id_funcionario_recibe,
                f.firma_staff_base64,              
                f.firma_funcionario_base64,
                f.nota_entrega,
                f.nota_recepcion,
                f.participantes_servicio,
                f.created_at,
                f.updated_at,
                ue.NOMBRE_USER as staff_nombre,
                ue.correo as staff_email,
                fun.nombre as funcionario_nombre,
                fun.cargo as funcionario_cargo,
                fun.empresa as funcionario_empresa
            FROM firmas f
            LEFT JOIN usuarios ue ON f.id_staff_entrega = ue.id
            LEFT JOIN funcionario fun ON f.id_funcionario_recibe = fun.id
            WHERE f.id_servicio = ?
            ORDER BY f.created_at DESC";

    log_debug("Preparando statement...");
    $stmt = $conn->prepare($sql);
    
    if (!$stmt) {
        log_debug("ERROR PREPARE: " . $conn->error);
        throw new Exception('Error prepare: ' . $conn->error);
    }
    
    log_debug("Statement preparado correctamente");
    $stmt->bind_param("i", $id_servicio);
    
    log_debug("Ejecutando query...");
    $stmt->execute();
    $result = $stmt->get_result();
    
    $firmas = [];
    $count = 0;
    
    while ($row = $result->fetch_assoc()) {
        $firmas[] = [
            'id' => (int)$row['id'],
            'idServicio' => (int)$row['id_servicio'],
            'idStaffEntrega' => (int)$row['id_staff_entrega'],
            'staffNombre' => $row['staff_nombre'],
            'staffEmail' => $row['staff_email'],
            'idFuncionarioRecibe' => (int)$row['id_funcionario_recibe'],
            'funcionarioNombre' => $row['funcionario_nombre'],
            'funcionarioCargo' => $row['funcionario_cargo'],
            'funcionarioEmpresa' => $row['funcionario_empresa'],
            'firmaStaffBase64' => $row['firma_staff_base64'],          
            'firmaFuncionarioBase64' => $row['firma_funcionario_base64'], 
            'notaEntrega' => $row['nota_entrega'],
            'notaRecepcion' => $row['nota_recepcion'],
            'participantesServicio' => $row['participantes_servicio'],
            'createdAt' => $row['created_at'],
            'updatedAt' => $row['updated_at']
        ];
        $count++;
    }

    log_debug("Firmas encontradas para servicio: $count");

    $response_data = [
        'success' => true,
        'data' => [
            'servicio' => [
                'id' => (int)$servicio['id'],
                'oServicio' => (int)$servicio['o_servicio'],
                'numeroServicioFormateado' => sprintf('#%04d', $servicio['o_servicio'])
            ],
            'firmas' => $firmas,
            'totalFirmas' => $count
        ]
    ];

    log_debug("Preparando respuesta JSON...");
    log_debug("Respuesta preparada (size: " . strlen(json_encode($response_data)) . " bytes)");
    
    sendJsonResponse($response_data, 200);
    
    log_debug("sendJsonResponse ejecutado");

} catch (Exception $e) {
    log_debug("EXCEPTION CAPTURADA");
    log_debug("Mensaje: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile());
    log_debug("Línea: " . $e->getLine());
    log_debug("Trace: " . $e->getTraceAsString());
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt_servicio)) {
        $stmt_servicio->close();
        log_debug("Statement servicio cerrado");
    }
    if (isset($stmt)) {
        $stmt->close();
        log_debug("Statement cerrado");
    }
    if (isset($conn)) {
        $conn->close();
        log_debug("Conexión cerrada");
    }
    log_debug("========================================");
    log_debug("REQUEST FINALIZADA");
    log_debug("========================================\n");
}
?>