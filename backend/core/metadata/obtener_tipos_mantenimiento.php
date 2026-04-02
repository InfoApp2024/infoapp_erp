<?php
require_once __DIR__ . '/../../login/auth_middleware.php';

try {
    $currentUser = optionalAuth();
    require __DIR__ . '/../../conexion.php';

    // 1. Obtener tipos de la tabla maestra
    $tipos = [];
    $res = $conn->query("SELECT nombre FROM tipos_mantenimiento ORDER BY nombre ASC");
    if ($res) {
        while ($row = $res->fetch_assoc()) {
            $tipos[] = trim(strtolower($row['nombre']));
        }
    }

    // 2. Obtener tipos históricos de la tabla servicios (por si acaso hay huérfanos)
    $resServ = $conn->query("SELECT DISTINCT tipo_mantenimiento FROM servicios WHERE tipo_mantenimiento IS NOT NULL AND tipo_mantenimiento != ''");
    if ($resServ) {
        while ($row = $resServ->fetch_assoc()) {
            $t = trim(strtolower($row['tipo_mantenimiento']));
            if (!in_array($t, $tipos)) {
                $tipos[] = $t;
            }
        }
    }

    // 3. Asegurar básicos
    $basicos = ['preventivo', 'correctivo', 'predictivo'];
    foreach ($basicos as $b) {
        if (!in_array($b, $tipos)) $tipos[] = $b;
    }

    $tipos = array_unique($tipos);
    sort($tipos);

    sendJsonResponse([
        'success' => true,
        'tipos' => array_values($tipos)
    ]);

} catch (Exception $e) {
    sendJsonResponse(['success' => false,'message' => $e->getMessage()], 500);
} finally {
    if (isset($conn)) $conn->close();
}
?>