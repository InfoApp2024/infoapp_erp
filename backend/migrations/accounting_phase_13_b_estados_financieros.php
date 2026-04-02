<?php
/**
 * Run Migration 13: Financial States
 * 1. Executes the SQL script
 * 2. Creates the default transitions
 * 3. Migrates existing services to the new financial state model
 */
require_once __DIR__ . '/../conexion.php';

echo "=== MIGRACION ESTADOS FINANCIEROS ===\n";

try {
    // 1. Ejecutar SQL base (ya no lo ejecutamos aquí porque master_setup lo ejecuta automáticamente en el bucle anterior)
    // $sqlContent = file_get_contents(__DIR__ . '/accounting_phase_13_estados_financieros.sql');
    
    // Sin embargo, por si se corre solo, lo mantenemos con verificación y try/catch.
    $sqlPath = __DIR__ . '/accounting_phase_13_estados_financieros.sql';
    if(file_exists($sqlPath)) {
        $sqlContent = file_get_contents($sqlPath);
        $conn->multi_query($sqlContent);
        do { if ($res = $conn->store_result()) { $res->free(); } } while ($conn->more_results() && $conn->next_result());
    }
    
    do {
        if ($res = $conn->store_result()) {
            $res->free();
        }
    } while ($conn->more_results() && $conn->next_result());
    
    echo "- Columnas y estados semilla insertados.\n";
    
    // 2. Obtener IDs de los Estados Generados
    $statesList = [
        'FIN_PENDIENTE', 'FIN_COTIZACION', 'FIN_CAUSADO', 
        'FIN_FACTURADO', 'FIN_ANULADO', 'FIN_PAGO_PARCIAL', 'FIN_PAGO_TOTAL'
    ];
    
    $sIds = [];
    foreach ($statesList as $code) {
        $res = $conn->query("SELECT id FROM estados_proceso WHERE estado_base_codigo = '$code' AND modulo = 'FINANCIERO' LIMIT 1");
        if ($row = $res->fetch_assoc()) {
            $sIds[$code] = (int)$row['id'];
        } else {
            throw new Exception("No se encontró el estado_proceso para: $code");
        }
    }
    
    // 3. Crear Transiciones Base (Evitar duplicados)
    $transitions = [
        // Pendiente -> ...
        [$sIds['FIN_PENDIENTE'], $sIds['FIN_COTIZACION'], 'Enviar Cotización'],
        [$sIds['FIN_PENDIENTE'], $sIds['FIN_CAUSADO'], 'Causar Servicio'],
        // Cotización -> ...
        [$sIds['FIN_COTIZACION'], $sIds['FIN_CAUSADO'], 'Causar Servicio'],
        [$sIds['FIN_COTIZACION'], $sIds['FIN_FACTURADO'], 'Generar Factura'],
        // Causado -> ...
        [$sIds['FIN_CAUSADO'], $sIds['FIN_COTIZACION'], 'Enviar Cotización'],
        [$sIds['FIN_CAUSADO'], $sIds['FIN_FACTURADO'], 'Generar Factura'],
        // Facturado -> ...
        [$sIds['FIN_FACTURADO'], $sIds['FIN_ANULADO'], 'Anular Factura'],
        [$sIds['FIN_FACTURADO'], $sIds['FIN_PAGO_PARCIAL'], 'Recibir Abono'],
        [$sIds['FIN_FACTURADO'], $sIds['FIN_PAGO_TOTAL'], 'Pago Completado'],
        // Anulado -> ...
        [$sIds['FIN_ANULADO'], $sIds['FIN_COTIZACION'], 'Re-enviar Cotización'],
        [$sIds['FIN_ANULADO'], $sIds['FIN_CAUSADO'], 'Volver a Causado'],
        // Pago Parcial -> ...
        [$sIds['FIN_PAGO_PARCIAL'], $sIds['FIN_PAGO_TOTAL'], 'Saldar Cuenta']
    ];
    
    $stmtT = $conn->prepare("INSERT IGNORE INTO transiciones_estado (estado_origen_id, estado_destino_id, nombre, modulo) VALUES (?, ?, ?, 'FINANCIERO')");
    foreach ($transitions as $t) {
        $stmtT->bind_param("iis", $t[0], $t[1], $t[2]);
        $stmtT->execute();
    }
    $stmtT->close();
    echo "- Transiciones base creadas.\n";
    
    // 4. Migración Retroactiva (Shadowing)
    echo "- Realizando migración retroactiva (esto puede tardar unos segundos)...\n";
    $conn->begin_transaction();
    
    $sqlMigrate = "
        SELECT s.id, fc.estado_comercial_cache
        FROM servicios s
        LEFT JOIN fac_control_servicios fc ON s.id = fc.servicio_id
        WHERE s.estado_financiero_id IS NULL
    ";
    
    $res = $conn->query($sqlMigrate);
    $count = 0;
    while ($row = $res->fetch_assoc()) {
        $sid = $row['id'];
        $cache = $row['estado_comercial_cache'] ?? '';
        
        $newId = $sIds['FIN_PENDIENTE']; // Default
        
        if ($cache === 'CAUSADO') {
            $newId = $sIds['FIN_CAUSADO'];
        } else if ($cache === 'FACTURADO_TOTAL' || $cache === 'FACTURACION_PARCIAL') {
            $newId = $sIds['FIN_FACTURADO'];
        }
        
        // El timestamp lo dejamos como el actual porque no sabemos históricamente cuándo ocurrió.
        $conn->query("UPDATE servicios SET estado_financiero_id = $newId, estado_fin_fecha_inicio = NOW() WHERE id = $sid");
        $count++;
    }
    
    $conn->commit();
    echo "- Migrados $count servicios a la nueva máquina de estados financieros.\n";
    
    echo "¡Completado exitosamente!\n";
    
} catch (Exception $e) {
    if (isset($conn)) $conn->rollback();
    echo "ERROR: " . $e->getMessage() . "\n";
}
