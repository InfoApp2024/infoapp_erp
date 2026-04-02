<?php
// verificar_primer_servicio.php - Verificar si es el primer servicio para permitir edición de número

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    // logAccess($currentUser, '/servicio/verificar_primer_servicio.php', 'check_first_service');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    require '../conexion.php';

    // ✅ VERIFICAR SI EXISTEN SERVICIOS EN LA TABLA
    $stmt = $conn->prepare("SELECT COUNT(*) as total_servicios FROM servicios");
    $stmt->execute();
    $result = $stmt->get_result();
    $row = $result->fetch_assoc();

    $total_servicios = intval($row['total_servicios'] ?? 0);
    $es_primer_servicio = ($total_servicios === 0);

    // ✅ OBTENER EL SIGUIENTE NÚMERO
    if ($es_primer_servicio) {
        $siguiente_numero = 1; // Primer servicio, usuario puede editar
    } else {
        // Calcular automáticamente el siguiente número
        $stmt_num = $conn->prepare("SELECT MAX(o_servicio) as ultimo_numero FROM servicios");
        $stmt_num->execute();
        $result_num = $stmt_num->get_result();
        $row_num = $result_num->fetch_assoc();
        $ultimo_numero = intval($row_num['ultimo_numero'] ?? 0);
        $siguiente_numero = $ultimo_numero + 1;
        $stmt_num->close();
    }

    sendJsonResponse([
        'success' => true,
        'es_primer_servicio' => $es_primer_servicio,
        'siguiente_numero' => $siguiente_numero,
        'total_servicios' => $total_servicios,
        'debug_info' => [
            'tabla_vacia' => ($total_servicios === 0),
            'puede_editar' => $es_primer_servicio,
            'numero_sugerido' => $siguiente_numero
        ]
    ]);
} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($stmt))
        $stmt->close();
    if (isset($conn))
        $conn->close();
}
