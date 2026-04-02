<?php
/**
 * SCRIPT: limpiar_y_proteger_workflow.php
 * PROPÓSITO: Consolidar estados duplicados y aplicar restricción de unicidad.
 */

require_once __DIR__ . '/../conexion.php';

// Intentar cargar auth si existe, si no, proceder (para ejecución manual controlada)
if (file_exists(__DIR__ . '/../login/auth_middleware.php')) {
    require_once __DIR__ . '/../login/auth_middleware.php';
    $user = optionalAuth();
}

header('Content-Type: application/json');

try {
    $conn->begin_transaction();

    // 1. IDENTIFICAR DUPLICADOS (Nombre + Módulo)
    $sql = "SELECT nombre_estado, modulo, COUNT(*) as cantidad, GROUP_CONCAT(id ORDER BY id ASC) as ids
            FROM estados_proceso
            GROUP BY nombre_estado, modulo
            HAVING cantidad > 1";

    $result = $conn->query($sql);
    $consolidatedCount = 0;

    while ($row = $result->fetch_assoc()) {
        $ids = explode(',', $row['ids']);
        $masterId = $ids[0]; // Conservamos el más antiguo (menor ID)
        array_shift($ids);   // Los demás son duplicados a eliminar
        $duplicateIds = implode(',', $ids);

        // a. Redirigir transiciones que usaban los IDs duplicados (Origen)
        $conn->query("UPDATE transiciones_estado SET estado_origen_id = $masterId WHERE estado_origen_id IN ($duplicateIds)");

        // b. Redirigir transiciones (Destino)
        $conn->query("UPDATE transiciones_estado SET estado_destino_id = $masterId WHERE estado_destino_id IN ($duplicateIds)");

        // c. Redirigir servicios (La tabla se llama 'servicio' según registros previos)
        $checkTable = $conn->query("SHOW TABLES LIKE 'servicio'");
        if ($checkTable->num_rows > 0) {
            $conn->query("UPDATE servicio SET estado_id = $masterId WHERE estado_id IN ($duplicateIds)");
        }

        // d. Eliminar los duplicados
        $conn->query("DELETE FROM estados_proceso WHERE id IN ($duplicateIds)");

        $consolidatedCount++;
    }

    // 2. APLICAR RESTRICCIÓN DE UNICIDAD
    // Primero verificamos si el índice ya existe para no fallar
    $checkIndex = $conn->query("SHOW INDEX FROM estados_proceso WHERE Key_name = 'idx_unique_nombre_modulo'");
    if ($checkIndex->num_rows === 0) {
        $conn->query("ALTER TABLE estados_proceso ADD UNIQUE INDEX idx_unique_nombre_modulo (nombre_estado, modulo)");
    }

    $conn->commit();

    echo json_encode([
        'success' => true,
        'message' => "Limpieza completada exitosamente.",
        'detalles' => [
            'grupos_consolidados' => $consolidatedCount,
            'indice_unico_aplicado' => true
        ]
    ], JSON_PRETTY_PRINT);

} catch (Exception $e) {
    if ($conn)
        $conn->rollback();
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => "Error durante la limpieza: " . $e->getMessage()
    ]);
}
?>