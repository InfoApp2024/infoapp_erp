<?php
// listar.php - Listar impuestos
// Protegido con JWT

error_reporting(E_ALL);
ini_set('display_errors', 0);
ini_set('log_errors', 1);

require_once '../login/auth_middleware.php';

try {
  $currentUser = requireAuth();
  logAccess($currentUser, 'impuestos/listar.php', 'list_taxes');

  require '../conexion.php';
  $conn->set_charset("utf8mb4");

  // Parámetros
  $search = isset($_GET['search']) ? trim($_GET['search']) : '';
  $estado = isset($_GET['estado']) ? (int) $_GET['estado'] : null;

  $sql = "SELECT id, nombre_impuesto, tipo_impuesto, porcentaje, base_minima_pesos, descripcion, estado FROM impuestos_config WHERE 1=1";
  $types = "";
  $params = [];

  if ($estado !== null) {
    $sql .= " AND estado = ?";
    $types .= "i";
    $params[] = $estado;
  }

  if (!empty($search)) {
    $sql .= " AND (nombre_impuesto LIKE ? OR tipo_impuesto LIKE ?)";
    $types .= "ss";
    $searchTerm = "%$search%";
    $params[] = $searchTerm;
    $params[] = $searchTerm;
  }

  $sql .= " ORDER BY nombre_impuesto ASC";

  $stmt = $conn->prepare($sql);
  if (!empty($params)) {
    $stmt->bind_param($types, ...$params);
  }

  $stmt->execute();
  $result = $stmt->get_result();

  $data = [];
  while ($row = $result->fetch_assoc()) {
    $row['id'] = (int) $row['id'];
    $row['porcentaje'] = (float) $row['porcentaje'];
    $row['base_minima_pesos'] = (float) $row['base_minima_pesos'];
    $row['estado'] = (int) $row['estado'];
    $data[] = $row;
  }

  sendJsonResponse(successResponse($data));
} catch (Exception $e) {
  sendJsonResponse(errorResponse($e->getMessage()), 500);
}
