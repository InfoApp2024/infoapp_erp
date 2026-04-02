<?php
/**
 * gestionar_periodos.php
 * Listar o actualizar estados de periodos contables
 */
require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    if ($_SERVER['REQUEST_METHOD'] === 'GET') {
        $sql = "SELECT p.*, 
                       u_ap.NOMBRE_USER as usuario_apertura_nombre,
                       u_ci.NOMBRE_USER as usuario_cierre_nombre
                FROM fin_periodos p
                LEFT JOIN usuarios u_ap ON p.usuario_apertura_id = u_ap.id
                LEFT JOIN usuarios u_ci ON p.usuario_cierre_id = u_ci.id
                ORDER BY p.anio DESC, p.mes DESC";
        $result = $conn->query($sql);
        sendJsonResponse(['success' => true, 'data' => $result->fetch_all(MYSQLI_ASSOC)]);
    } elseif ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $data = json_decode(file_get_contents('php://input'), true);
        $action = $data['action'] ?? 'toggle';

        if ($action === 'create') {
            $anio = (int) $data['anio'];
            $mes = (int) $data['mes'];
            $fecha_inicio = $data['fecha_inicio'];
            $fecha_fin = $data['fecha_fin'];

            // 1. Validar solapamiento (Overlap)
            $sqlCheck = "SELECT id FROM fin_periodos 
                         WHERE (fecha_inicio <= ? AND fecha_fin >= ?) 
                         OR (fecha_inicio <= ? AND fecha_fin >= ?)";
            $stmtC = $conn->prepare($sqlCheck);
            $stmtC->bind_param("ssss", $fecha_fin, $fecha_inicio, $fecha_inicio, $fecha_fin);
            $stmtC->execute();
            if ($stmtC->get_result()->num_rows > 0) {
                throw new Exception("El rango de fechas se solapa con un periodo existente.");
            }
            $stmtC->close();

            // 2. Insertar nuevo periodo
            $sqlInsert = "INSERT INTO fin_periodos (anio, mes, fecha_inicio, fecha_fin, estado, usuario_apertura_id, fecha_apertura) 
                          VALUES (?, ?, ?, ?, 'ABIERTO', ?, NOW())";
            $stmtI = $conn->prepare($sqlInsert);
            $stmtI->bind_param("iissi", $anio, $mes, $fecha_inicio, $fecha_fin, $currentUser['id']);
            $stmtI->execute();

            sendJsonResponse(['success' => true, 'message' => 'Periodo creado exitosamente']);

        } else {
            // Acción: toggle (Abrir/Cerrar)
            $periodo_id = $data['id'];
            $nuevo_estado = $data['estado']; // 'ABIERTO', 'CERRADO'

            if ($nuevo_estado === 'ABIERTO') {
                $sql = "UPDATE fin_periodos SET estado = ?, usuario_apertura_id = ?, fecha_apertura = NOW() WHERE id = ?";
            } else {
                $sql = "UPDATE fin_periodos SET estado = ?, usuario_cierre_id = ?, fecha_cierre = NOW() WHERE id = ?";
            }

            $stmt = $conn->prepare($sql);
            $stmt->bind_param("sii", $nuevo_estado, $currentUser['id'], $periodo_id);
            $stmt->execute();
            $stmt->close();

            sendJsonResponse(['success' => true, 'message' => 'Estado de periodo actualizado']);
        }
    }

} catch (Exception $e) {
    sendJsonResponse(errorResponse($e->getMessage()), 500);
}
