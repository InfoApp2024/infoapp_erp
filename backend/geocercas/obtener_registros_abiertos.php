<?php
// backend/geocercas/obtener_registros_abiertos.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();
    require '../conexion.php';

    // Configurar zona horaria de Colombia (UTC-5)
    date_default_timezone_set('America/Bogota');
    $conn->query("SET time_zone = '-05:00'");

    $usuario_id = $currentUser['id'];

    // Obtener todos los registros abiertos (sin fecha_salida) del usuario
    $sql = "SELECT 
              r.id as registro_id,
              r.geocerca_id,
              r.fecha_ingreso,
              r.foto_ingreso,
              g.nombre as geocerca_nombre,
              g.latitud,
              g.longitud,
              g.radio
            FROM registros_geocerca r
            INNER JOIN geocercas g ON r.geocerca_id = g.id
            WHERE r.usuario_id = ?
              AND r.fecha_salida IS NULL
            ORDER BY r.fecha_ingreso DESC";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param('i', $usuario_id);
    $stmt->execute();
    $result = $stmt->get_result();

    $registros = [];
    while ($row = $result->fetch_assoc()) {
        $registros[] = [
            'registro_id' => intval($row['registro_id']),
            'geocerca_id' => intval($row['geocerca_id']),
            'geocerca_nombre' => $row['geocerca_nombre'],
            'fecha_ingreso' => $row['fecha_ingreso'],
            'foto_ingreso' => $row['foto_ingreso'],
            'latitud' => floatval($row['latitud']),
            'longitud' => floatval($row['longitud']),
            'radio' => floatval($row['radio'])
        ];
    }

    sendJsonResponse([
        'success' => true,
        'registros_abiertos' => $registros,
        'total' => count($registros)
    ]);

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
