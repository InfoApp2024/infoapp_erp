<?php
// backend/geocercas/monitoreo_tiempo_real.php
error_reporting(E_ALL);
ini_set('display_errors', 0);

require_once '../login/auth_middleware.php';

try {
    $currentUser = requireAuth();

    // TODO: Verificar permiso 'geocercas.monitoreo'
    // if (!hasPermission($currentUser, 'geocercas', 'monitoreo')) {
    //     throw new Exception('No tiene permisos para acceder al monitoreo');
    // }

    require '../conexion.php';

    // Configurar zona horaria de Colombia (UTC-5)
    date_default_timezone_set('America/Bogota');
    $conn->query("SET time_zone = '-05:00'");

    // Obtener todas las geocercas
    $sqlGeocercas = "SELECT id, nombre, latitud, longitud, radio 
                     FROM geocercas 
                     ORDER BY nombre";

    $resultGeocercas = $conn->query($sqlGeocercas);

    $geocercas = [];

    while ($geocerca = $resultGeocercas->fetch_assoc()) {
        // Para cada geocerca, obtener el personal actualmente dentro
        $sqlPersonal = "SELECT 
                          r.id as registro_id,
                          r.usuario_id,
                          u.NOMBRE_USER as nombre_usuario,
                          r.fecha_ingreso,
                          r.foto_ingreso,
                          TIMESTAMPDIFF(MINUTE, r.fecha_ingreso, NOW()) as minutos_dentro
                        FROM registros_geocerca r
                        INNER JOIN usuarios u ON r.usuario_id = u.id
                        WHERE r.geocerca_id = ?
                          AND r.fecha_salida IS NULL
                        ORDER BY r.fecha_ingreso DESC";

        $stmtPersonal = $conn->prepare($sqlPersonal);
        $stmtPersonal->bind_param('i', $geocerca['id']);
        $stmtPersonal->execute();
        $resultPersonal = $stmtPersonal->get_result();

        $personalActivo = [];
        while ($persona = $resultPersonal->fetch_assoc()) {
            // Calcular tiempo de permanencia en formato legible
            $minutos = $persona['minutos_dentro'];
            $horas = floor($minutos / 60);
            $mins = $minutos % 60;

            $tiempoDentro = '';
            if ($horas > 0) {
                $tiempoDentro = "{$horas}h {$mins}m";
            } else {
                $tiempoDentro = "{$mins}m";
            }

            $personalActivo[] = [
                'registro_id' => $persona['registro_id'],
                'usuario_id' => $persona['usuario_id'],
                'nombre' => $persona['nombre_usuario'],
                'fecha_ingreso' => $persona['fecha_ingreso'],
                'foto_ingreso' => $persona['foto_ingreso'],
                'minutos_dentro' => $minutos,
                'tiempo_dentro' => $tiempoDentro
            ];
        }

        $geocercas[] = [
            'id' => $geocerca['id'],
            'nombre' => $geocerca['nombre'],
            'latitud' => floatval($geocerca['latitud']),
            'longitud' => floatval($geocerca['longitud']),
            'radio' => floatval($geocerca['radio']),
            'activo' => true, // Todas las geocercas se consideran activas
            'personal_activo' => $personalActivo,
            'cantidad_personal' => count($personalActivo)
        ];
    }

    // Contar totales
    $totalPersonal = 0;
    $geocercasActivas = 0;

    foreach ($geocercas as $geo) {
        $totalPersonal += $geo['cantidad_personal'];
        if ($geo['cantidad_personal'] > 0) {
            $geocercasActivas++;
        }
    }

    sendJsonResponse([
        'success' => true,
        'geocercas' => $geocercas,
        'estadisticas' => [
            'total_geocercas' => count($geocercas),
            'geocercas_activas' => $geocercasActivas,
            'total_personal' => $totalPersonal
        ],
        'timestamp' => date('Y-m-d H:i:s')
    ]);

} catch (Exception $e) {
    sendJsonResponse([
        'success' => false,
        'message' => $e->getMessage()
    ], 500);
}
