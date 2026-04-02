<?php

/**
 * GET /API_Infoapp/inventory/items/get_unique_locations.php
 * 
 * Endpoint para obtener lista de ubicaciones únicas
 */

require_once '../../login/auth_middleware.php';
$currentUser = requireAuth();
// logAccess($currentUser, '/inventory/items/get_unique_locations.php', 'list_locations');

header('Content-Type: application/json');

require_once '../../conexion.php';

try {
  if ($conn->connect_error) {
    throw new Exception("Error de conexión: " . $conn->connect_error);
  }

  $sql = "SELECT DISTINCT location FROM inventory_items WHERE location IS NOT NULL AND location != '' ORDER BY location ASC";
  $result = $conn->query($sql);

  $locations = [];
  if ($result) {
    while ($row = $result->fetch_assoc()) {
      $locations[] = $row['location'];
    }
  }

  http_response_code(200);
  echo json_encode([
    'success' => true,
    'data' => $locations
  ], JSON_UNESCAPED_UNICODE);
} catch (Exception $e) {
  http_response_code(500);
  echo json_encode([
    'success' => false,
    'message' => 'Error interno del servidor',
    'errors' => ['general' => $e->getMessage()]
  ], JSON_UNESCAPED_UNICODE);
}

if (isset($conn)) {
  $conn->close();
}
