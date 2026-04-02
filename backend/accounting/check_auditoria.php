<?php
// backend/accounting/check_auditoria.php
// Consulta si un servicio ha sido auditado y si existen auditores en el sistema.
// GET ?servicio_id=X

require_once '../login/auth_middleware.php';
require_once '../servicio/helpers/ServiceStatusValidator.php';

try {
    $currentUser = requireAuth();
    logAccess($currentUser, '/accounting/check_auditoria.php', 'check_auditoria');

    if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
        sendJsonResponse(errorResponse('Método no permitido'), 405);
    }

    $servicio_id = isset($_GET['servicio_id']) ? intval($_GET['servicio_id']) : null;
    if (!$servicio_id) {
        sendJsonResponse(errorResponse('servicio_id es requerido'), 400);
    }

    require '../conexion.php';

    // 1. Verificar si existe al menos un auditor en el sistema
    $stmtAuditores = $conn->prepare(
        "SELECT id, NOMBRE_USER, es_auditor, ESTADO_USER FROM usuarios WHERE es_auditor = 1 AND ESTADO_USER = 'activo'"
    );
    $stmtAuditores->execute();
    $resAuditores = $stmtAuditores->get_result();
    $auditoresActivos = [];
    while ($row = $resAuditores->fetch_assoc()) {
        $auditoresActivos[] = $row['NOMBRE_USER'];
    }
    $totalAuditores = count($auditoresActivos);

    $hayAuditores = $totalAuditores > 0;

    // 2. Obtener el ciclo actual de auditoría para este servicio
    $stmtCiclo = $conn->prepare("SELECT ciclo_actual FROM fac_audit_ciclos WHERE servicio_id = ? LIMIT 1");
    $stmtCiclo->bind_param("i", $servicio_id);
    $stmtCiclo->execute();
    $cicloRow = $stmtCiclo->get_result()->fetch_assoc();
    $stmtCiclo->close();
    $ciclo_actual = $cicloRow ? (int) $cicloRow['ciclo_actual'] : 1;

    // 3. Obtener el HISTORIAL COMPLETO de auditorías para este servicio (Trazabilidad)
    $stmtHistorial = $conn->prepare("
        SELECT
            fa.id,
            fa.fecha_auditoria,
            fa.comentario,
            fa.ciclo,
            u.NOMBRE_USER AS auditor_nombre,
            u.NOMBRE_USER   AS auditor_usuario,
            u.id            AS auditor_id
        FROM fac_auditorias_servicio fa
        JOIN usuarios u ON fa.auditor_id = u.id
        WHERE fa.servicio_id = ?
        ORDER BY fa.fecha_auditoria DESC
    ");
    $stmtHistorial->bind_param("i", $servicio_id);
    $stmtHistorial->execute();
    $resHistorial = $stmtHistorial->get_result();
    
    $historial = [];
    $auditoria_actual = null;
    
    while ($row = $resHistorial->fetch_assoc()) {
        $auditItem = [
            'id' => (int) $row['id'],
            'fecha_auditoria' => $row['fecha_auditoria'],
            'comentario' => $row['comentario'],
            'ciclo' => (int) $row['ciclo'],
            'auditor_id' => (int) $row['auditor_id'],
            'auditor_nombre' => $row['auditor_nombre'],
            'auditor_usuario' => $row['auditor_usuario'],
        ];
        $historial[] = $auditItem;
        
        // El auditoria_actual es la que corresponda al ciclo_actual
        if ($auditItem['ciclo'] === $ciclo_actual && $auditoria_actual === null) {
            $auditoria_actual = $auditItem;
        }
    }
    $stmtHistorial->close();

    $auditado = $auditoria_actual !== null;

    // 4. Verificar si el servicio está apto para auditoría (pre-vuelo)
    $esAptoParaLegalizado = ServiceStatusValidator::esAptoParaAuditoria($conn, $servicio_id);

    sendJsonResponse([
        'success' => true,
        'data' => [
            'hay_auditores' => $hayAuditores,
            'auditado' => $auditado,
            'es_apto_para_legalizado' => $esAptoParaLegalizado,
            'auditor_id' => $auditado ? $auditoria_actual['auditor_id'] : null,
            'auditor_nombre' => $auditado ? $auditoria_actual['auditor_nombre'] : implode(', ', $auditoresActivos),
            'auditor_usuario' => $auditado ? $auditoria_actual['auditor_usuario'] : null,
            'fecha_auditoria' => $auditado ? $auditoria_actual['fecha_auditoria'] : null,
            'comentario' => $auditado ? $auditoria_actual['comentario'] : null,
            'historial' => $historial // ✅ NUEVO: Lista completa de auditorías
        ]
    ]);

} catch (Exception $e) {
    sendJsonResponse(errorResponse('Error: ' . $e->getMessage()), 500);
} finally {
    if (isset($stmtAuditores))
        $stmtAuditores->close();
    if (isset($stmtCiclo))
        $stmtCiclo->close();
    if (isset($stmtHistorial))
        $stmtHistorial->close();
    if (isset($conn))
        $conn->close();
}
