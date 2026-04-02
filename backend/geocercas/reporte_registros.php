<?php
// backend/geocercas/reporte_registros.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
  $currentUser = requireAuth();

  require '../conexion.php';

  // Filtros
  $usuario_id = isset($_GET['usuario_id']) ? intval($_GET['usuario_id']) : null;
  $geocerca_id = isset($_GET['geocerca_id']) ? intval($_GET['geocerca_id']) : null;
  $fecha_inicio = isset($_GET['fecha_inicio']) ? $_GET['fecha_inicio'] : null;
  $fecha_fin = isset($_GET['fecha_fin']) ? $_GET['fecha_fin'] : null;

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

  $whereClause = implode(" AND ", $where);

  // Query principal con Joins y cálculo de duración
  // Nota: DATE_FORMAT(r.fecha_ingreso, '%W') devuelve el nombre del día en inglés. 
  // Para español, se puede manejar en el frontend o usar SET lc_time_names.
  $sql = "SELECT 
                u.NOMBRE_USER as usuario,
                g.nombre as lugar,
                DATE(r.fecha_ingreso) as fecha,
                TIME(r.fecha_ingreso) as hora_ingreso,
                TIME(r.fecha_salida) as hora_salida,
                TIMEDIFF(r.fecha_salida, r.fecha_ingreso) as tiempo_total,
                r.fecha_ingreso,
                r.observaciones
            FROM registros_geocerca r
            JOIN geocercas g ON r.geocerca_id = g.id
            JOIN usuarios u ON r.usuario_id = u.id
            WHERE $whereClause
            ORDER BY r.fecha_ingreso DESC";

  $stmt = $conn->prepare($sql);

  if (!empty($types)) {
    $stmt->bind_param($types, ...$params);
  }

  $stmt->execute();
  $result = $stmt->get_result();

  $registros = [];
  while ($row = $result->fetch_assoc()) {
    $registros[] = $row;
  }

  sendJsonResponse([
    'success' => true,
    'data' => $registros
  ]);
} catch (Exception $e) {
  sendJsonResponse([
    'success' => false,
    'message' => $e->getMessage()
  ], 500);
}
