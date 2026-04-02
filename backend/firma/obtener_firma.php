<?php
// obtener_firma.php - Protegido con JWT
// FINAL: Staff de usuarios, Funcionario de funcionario

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

define('DEBUG_LOG', __DIR__ . '/debug_obtener_firma.txt');

function log_debug($msg)
{
    $time = date('Y-m-d H:i:s');
    $memoryMB = round(memory_get_usage() / 1024 / 1024, 2);
    file_put_contents(DEBUG_LOG, "[$time][MEM: {$memoryMB}MB] $msg\n", FILE_APPEND);
}

register_shutdown_function(function () {
    $error = error_get_last();
    if ($error !== null && in_array($error['type'], [E_ERROR, E_PARSE, E_CORE_ERROR, E_COMPILE_ERROR])) {
        log_debug("ERROR FATAL: " . $error['message']);
        log_debug("Archivo: " . $error['file'] . " Línea: " . $error['line']);
    }
});

set_exception_handler(function ($e) {
    log_debug("EXCEPCIÓN NO MANEJADA: " . $e->getMessage());
    log_debug("Archivo: " . $e->getFile() . " Línea: " . $e->getLine());
    log_debug("Stack: " . $e->getTraceAsString());
});

log_debug("========================================");
log_debug("NUEVA REQUEST OBTENER FIRMA");
log_debug("========================================");
log_debug("IP: " . ($_SERVER['REMOTE_ADDR'] ?? 'unknown'));
log_debug("Método: " . $_SERVER['REQUEST_METHOD']);
log_debug("URI: " . ($_SERVER['REQUEST_URI'] ?? 'unknown'));

require_once '../login/auth_middleware.php';

try {
    log_debug("auth_middleware cargado");

    $currentUser = requireAuth();
    log_debug("Usuario autenticado: " . $currentUser['usuario'] . " (ID: " . $currentUser['id'] . ")");

    logAccess($currentUser, '/firma/obtener_firma.php', 'get_firma');
    log_debug("Acceso registrado");

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        log_debug("Método no permitido: " . $_SERVER['REQUEST_METHOD']);
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    log_debug("Requiriendo conexión...");
    require '../conexion.php';
    log_debug("conexion.php cargado");

    // Obtener ID de la firma
    $firma_id = isset($_GET['id']) ? intval($_GET['id']) : null;

    if (!$firma_id) {
        log_debug("ID de firma no proporcionado");
        sendJsonResponse(errorResponse('ID de firma requerido'), 400);
    }

    log_debug("Buscando firma con ID: $firma_id");

    // Query con todos los datos relacionados, incluyendo las firmas en base64
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
                s.id as servicio_id,
                s.o_servicio,
                s.orden_cliente,
                s.tipo_mantenimiento,
                s.centro_costo,
                s.fecha_ingreso,
                e.id as equipo_id,
                e.placa,
                e.nombre_empresa,
                e.marca,
                e.modelo,
                ue_user.NOMBRE_USER as user_nombre,
                ue_user.correo as user_email,
                ue_user.telefono as user_telefono,
                CONCAT(ue_staff.first_name, ' ', ue_staff.last_name) as staff_nombre,
                ue_staff.email as staff_email,
                ue_staff.phone as staff_telefono,
                fun.id as funcionario_id,
                fun.nombre as funcionario_nombre,
                fun.cargo as funcionario_cargo,
                fun.empresa as funcionario_empresa
            FROM firmas f
            INNER JOIN servicios s ON f.id_servicio = s.id
            INNER JOIN equipos e ON s.id_equipo = e.id
            LEFT JOIN usuarios ue_user ON f.id_staff_entrega = ue_user.id AND f.id_staff_entrega <= 1000000
            LEFT JOIN staff ue_staff ON (f.id_staff_entrega - 1000000) = ue_staff.id AND f.id_staff_entrega > 1000000
            LEFT JOIN funcionario fun ON f.id_funcionario_recibe = fun.id
            WHERE f.id = ?";

    log_debug("Preparando statement...");
    $stmt = $conn->prepare($sql);

    if (!$stmt) {
        log_debug("ERROR PREPARE: " . $conn->error);
        throw new Exception('Error prepare: ' . $conn->error);
    }

    log_debug("Statement preparado correctamente");
    $stmt->bind_param("i", $firma_id);

    log_debug("Ejecutando query...");
    $stmt->execute();
    $result = $stmt->get_result();

    if ($result->num_rows === 0) {
        log_debug("Firma no encontrada con ID: $firma_id");
        sendJsonResponse(errorResponse('Firma no encontrada'), 404);
    }

    $row = $result->fetch_assoc();
    log_debug("Firma encontrada");

    // Construir respuesta completa
    $response_data = [
        'success' => true,
        'data' => [
            'id' => (int) $row['id'],
            'firma' => [
                'firmaStaffBase64' => $row['firma_staff_base64'],
                'firmaFuncionarioBase64' => $row['firma_funcionario_base64'],
                'notaEntrega' => $row['nota_entrega'],
                'notaRecepcion' => $row['nota_recepcion'],
                'participantesServicio' => $row['participantes_servicio'],
                'createdAt' => $row['created_at'],
                'updatedAt' => $row['updated_at']
            ],
            'servicio' => [
                'id' => (int) $row['servicio_id'],
                'oServicio' => (int) $row['o_servicio'],
                'numeroServicioFormateado' => sprintf('#%04d', $row['o_servicio']),
                'ordenCliente' => $row['orden_cliente'],
                'tipoMantenimiento' => $row['tipo_mantenimiento'],
                'centroCosto' => $row['centro_costo'],
                'fechaIngreso' => $row['fecha_ingreso']
            ],
            'equipo' => [
                'id' => (int) $row['equipo_id'],
                'placa' => $row['placa'],
                'nombreEmpresa' => $row['nombre_empresa'],
                'marca' => $row['marca'],
                'modelo' => $row['modelo']
            ],
            'staffEntrega' => [
                'id' => (int) $row['id_staff_entrega'],
                'nombre' => $row['id_staff_entrega'] > 1000000 ? $row['staff_nombre'] : $row['user_nombre'],
                'email' => $row['id_staff_entrega'] > 1000000 ? $row['staff_email'] : $row['user_email'],
                'telefono' => $row['id_staff_entrega'] > 1000000 ? $row['staff_telefono'] : $row['user_telefono']
            ],
            'funcionarioRecibe' => [
                'id' => (int) $row['funcionario_id'],
                'nombre' => $row['funcionario_nombre'],
                'cargo' => $row['funcionario_cargo'],
                'empresa' => $row['funcionario_empresa']
            ]
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