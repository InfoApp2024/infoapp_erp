<?php
/**
 * devolver_a_operaciones.php
 * Permite retornar un servicio legalizado a operaciones para correcciones.
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    $data = json_decode(file_get_contents('php://input'), true);

    $servicio_id = $data['servicio_id'] ?? null;
    $motivo = trim($data['motivo'] ?? '');

    if (!$servicio_id || empty($motivo)) {
        throw new Exception("ID de servicio y motivo son requeridos.");
    }

    require '../conexion.php';
    require_once '../servicio/helpers/trazabilidad_helper.php';

    // 1. Verificar estado actual y estado comercial (causación)
    // NOTA: Se usa LEFT JOIN para que un estado huérfano no oculte el servicio.
    $sqlCheck = "SELECT s.id, s.estado, ep.estado_base_codigo, fcs.estado_comercial_cache 
                 FROM servicios s
                 LEFT JOIN estados_proceso ep ON s.estado = ep.id
                 LEFT JOIN fac_control_servicios fcs ON s.id = fcs.servicio_id
                 WHERE s.id = ?";
    $stmt = $conn->prepare($sqlCheck);
    $stmt->bind_param("i", $servicio_id);
    $stmt->execute();
    $servicio = $stmt->get_result()->fetch_assoc();
    $stmt->close();

    if (!$servicio) {
        throw new Exception("Servicio #$servicio_id no encontrado en la base de datos.");
    }

    $estadoBase = strtoupper(trim($servicio['estado_base_codigo'] ?? ''));
    if ($estadoBase !== 'LEGALIZADO') {
        throw new Exception("Solo servicios en estado LEGALIZADO pueden ser devueltos. Estado actual: '{$estadoBase}'.");
    }

    if ($servicio['estado_comercial_cache'] === 'CAUSADO') {
        throw new Exception("No se puede retornar un servicio que ya ha sido CAUSADO. La causación es un proceso de revisión final y oficial.");
    }

    // 2. Buscar el estado al que retornar (Preferiblemente EN_EJECUCION o ASIGNADO)
    $sqlEstado = "SELECT id FROM estados_proceso 
                  WHERE estado_base_codigo IN ('EN_EJECUCION', 'EN_PROCESO', 'ASIGNADO') 
                  AND modulo = 'servicio' 
                  ORDER BY FIELD(estado_base_codigo, 'EN_EJECUCION', 'EN_PROCESO', 'ASIGNADO') ASC 
                  LIMIT 1";
    $resE = $conn->query($sqlEstado);
    $nuevo_estado = $resE->fetch_assoc();

    if (!$nuevo_estado) {
        // Fallback: buscar el primer estado disponible que no sea terminal
        $sqlEstado = "SELECT id FROM estados_proceso 
                      WHERE estado_base_codigo NOT IN ('LEGALIZADO', 'CANCELADO', 'CERRADO') 
                      AND modulo = 'servicio'
                      ORDER BY orden ASC LIMIT 1";
        $resE = $conn->query($sqlEstado);
        $nuevo_estado = $resE->fetch_assoc();
    }

    $conn->begin_transaction();

    // 3. Cambiar estado del servicio, resetear banderas de finalización y guardar motivo
    // Se incluye ADVERTENCIA LEGAL en la columna razon para trazabilidad visible
    $sqlUpdate = "UPDATE servicios SET 
                    estado = ?, 
                    razon = ?, 
                    fecha_finalizacion = NULL 
                  WHERE id = ?";
    $stmtU = $conn->prepare($sqlUpdate);

    // Concatenamos el motivo de devolución con el descargo de responsabilidad legal
    $descripcion_razon = "DEVOLUCIÓN COMERCIAL: " . $motivo . " | ADVERTENCIA: Servicio modificado post-firma por orden de Financiero.";

    $stmtU->bind_param("isi", $nuevo_estado['id'], $descripcion_razon, $servicio_id);
    $stmtU->execute();
    $stmtU->close();

    // 3.1 Registrar Nota en el Servicio para visibilidad manual (HISTORIAL)
    $stmtNota = $conn->prepare("INSERT INTO notas (id_servicio, nota, fecha, hora, usuario, usuario_id) VALUES (?, ?, CURDATE(), CURTIME(), ?, ?)");
    $stmtNota->bind_param("issi", $servicio_id, $descripcion_razon, $currentUser['usuario'], $currentUser['id']);
    $stmtNota->execute();
    $stmtNota->close();

    // 4. ELIMINAR el snapshot de facturación y su historial de ajustes (Requerimiento #3.22)
    $conn->query("DELETE FROM fac_control_servicios WHERE servicio_id = $servicio_id");
    $conn->query("DELETE FROM fac_snapshot_ajustes WHERE servicio_id = $servicio_id");

    // 4.1 INCREMENTAR el ciclo de auditoría (Requerimiento #3.23 — Trazabilidad Multi-Ciclo)
    // Wrapped en try-catch para degradar graciosamente si la migración aún no fue ejecutada.
    try {
        $conn->query("
            INSERT INTO fac_audit_ciclos (servicio_id, ciclo_actual)
            VALUES ($servicio_id, 2)
            ON DUPLICATE KEY UPDATE ciclo_actual = ciclo_actual + 1
        ");
    } catch (Exception $eCiclo) {
        // Si la tabla no existe (migración pendiente), lo ignoramos y continuamos.
        error_log("[devolver_a_operaciones] fac_audit_ciclos unavailable: " . $eCiclo->getMessage());
    }

    // 5. Registrar Log de Auditoría Operativo (Trazabilidad)
    TrazabilidadHelper::registrarTransicionEstado($conn, $servicio_id, $nuevo_estado['id'], $currentUser['id']);

    $conn->commit();

    sendJsonResponse([
        'success' => true,
        'message' => "Servicio devuelto a operaciones exitosamente."
    ]);

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    sendJsonResponse(errorResponse($e->getMessage()), 500);
} finally {
    if (isset($conn))
        $conn->close();
}
