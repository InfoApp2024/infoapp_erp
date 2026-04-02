<?php
// backend/geocercas/listar_registros.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    require '../conexion.php';

    // Filtros opcionales
    $usuario_id = isset($_GET['usuario_id']) ? intval($_GET['usuario_id']) : null;
    $geocerca_id = isset($_GET['geocerca_id']) ? intval($_GET['geocerca_id']) : null;
    $fecha_inicio = isset($_GET['fecha_inicio']) ? $_GET['fecha_inicio'] : null;
    $fecha_fin = isset($_GET['fecha_fin']) ? $_GET['fecha_fin'] : null;

    // Paginación
    $page = isset($_GET['page']) ? intval($_GET['page']) : 1;
    $limit = isset($_GET['limit']) ? intval($_GET['limit']) : 20;
    $offset = ($page - 1) * $limit;

    // Construir query
    $where = ["1=1"];
    $params = [];
    $types = "";

    if ($usuario_id) {
        $where[] = "r.usuario_id = ?";
        $params[] = $usuario_id;
        $types .= "i";
    }

    if ($geocerca_id) {
        $where[] = "r.geocerca_id = ?";
        $params[] = $geocerca_id;
        $types .= "i";
    }

    if ($fecha_inicio) {
        $where[] = "DATE(r.fecha_ingreso) >= ?";
        $params[] = $fecha_inicio;
        $types .= "s";
    }

    if ($fecha_fin) {
        $where[] = "DATE(r.fecha_ingreso) <= ?";
        $params[] = $fecha_fin;
        $types .= "s";
    }

    // Si no es admin, solo puede ver sus propios registros (opcional)
    // if ($currentUser['rol'] !== 'administrador') {
    //     $where[] = "r.usuario_id = ?";
    //     $params[] = $currentUser['id'];
    //     $types .= "i";
    // }

    $whereClause = implode(" AND ", $where);

    // Query principal con Joins para traer nombres
    $sql = "SELECT r.*, 
                   g.nombre as nombre_geocerca, 
                   u.NOMBRE_USER as nombre_usuario,
                   r.foto_ingreso,
                   r.foto_salida,
                   r.fecha_captura_ingreso,
                   r.fecha_captura_salida,
                   TIMEDIFF(r.fecha_salida, r.fecha_ingreso) as duracion
            FROM registros_geocerca r
            JOIN geocercas g ON r.geocerca_id = g.id
            JOIN usuarios u ON r.usuario_id = u.id
            WHERE $whereClause
            ORDER BY r.fecha_ingreso DESC
            LIMIT ? OFFSET ?";

    $params[] = $limit;
    $params[] = $offset;
    $types .= "ii";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param($types, ...$params);
    $stmt->execute();
    $result = $stmt->get_result();

    $registros = [];
    while ($row = $result->fetch_assoc()) {
        $registros[] = $row;
    }

    // Contar total para paginación
    $sqlCount = "SELECT COUNT(*) as total FROM registros_geocerca r WHERE $whereClause";
    $stmtCount = $conn->prepare($sqlCount);
    if (!empty($types)) {
        // Remover limit y offset de params/types para el count
        $typesCount = substr($types, 0, -2);
        $paramsCount = array_slice($params, 0, -2);
        if (!empty($paramsCount)) {
            $stmtCount->bind_param($typesCount, ...$paramsCount);
        }
    }
    $stmtCount->execute();
    $total = $stmtCount->get_result()->fetch_assoc()['total'];

    sendJsonResponse([
        'success' => true,
        'data' => $registros,
        'pagination' => [
            'total' => $total,
            'page' => $page,
            'limit' => $limit,
            'pages' => ceil($total / $limit)
        ]
    ]);
} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
