<?php
/**
 * fix_workflow_system.php
 * Script de reparación para asegurar que el sistema de workflow tenga sus tablas y columnas correctas.
 */

require_once __DIR__ . '/../../conexion.php';

echo "<html><body style='font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px;'>";
echo "<h2>--- Reparación del Sistema de Workflow ---</h2>";
echo "<pre style='background: #252526; padding: 15px; border-radius: 5px; border: 1px solid #3e3e42;'>";

try {
    $conn->begin_transaction();

    // 1. Crear tabla estados_base
    echo "1. ASEGURANDO TABLA estados_base...\n";
    $conn->query("CREATE TABLE IF NOT EXISTS estados_base (
        id INT AUTO_INCREMENT PRIMARY KEY,
        codigo VARCHAR(20) UNIQUE NOT NULL,
        nombre VARCHAR(50) NOT NULL,
        descripcion TEXT,
        es_final BOOLEAN DEFAULT 0,
        permite_edicion BOOLEAN DEFAULT 1,
        orden INT DEFAULT 0,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // 2. Poblar estados_base
    echo "2. POBLANDO estados_base...\n";
    $estados_base = [
        ['ABIERTO', 'Abierto', 'Servicio registrado', 0, 1, 1],
        ['PROGRAMADO', 'Programado', 'Servicio con fecha', 0, 1, 2],
        ['ASIGNADO', 'Asignado', 'Servicio con técnico', 0, 1, 3],
        ['EN_EJECUCION', 'En Ejecución', 'Trabajo iniciado', 0, 1, 4],
        ['FINALIZADO', 'Finalizado', 'Trabajo terminado técnicamente', 1, 0, 5],
        ['CERRADO', 'Cerrado', 'Cierre administrativo', 1, 0, 6],
        ['CANCELADO', 'Cancelado', 'Servicio anulado', 1, 0, 7]
    ];
    $stmtBase = $conn->prepare("INSERT INTO estados_base (codigo, nombre, descripcion, es_final, permite_edicion, orden) VALUES (?, ?, ?, ?, ?, ?) ON DUPLICATE KEY UPDATE nombre=VALUES(nombre)");
    foreach ($estados_base as $eb) {
        $stmtBase->bind_param("sssiis", $eb[0], $eb[1], $eb[2], $eb[3], $eb[4], $eb[5]);
        $stmtBase->execute();
    }

    // 3. Crear tabla estados_proceso
    echo "3. ASEGURANDO TABLA estados_proceso...\n";
    $conn->query("CREATE TABLE IF NOT EXISTS estados_proceso (
        id INT AUTO_INCREMENT PRIMARY KEY,
        nombre_estado VARCHAR(100) NOT NULL,
        color VARCHAR(20),
        estado_base_codigo VARCHAR(20) DEFAULT 'ABIERTO',
        bloquea_cierre BOOLEAN DEFAULT 0,
        modulo VARCHAR(50) DEFAULT 'servicio',
        orden INT DEFAULT 0,
        INDEX idx_modulo (modulo),
        INDEX idx_base (estado_base_codigo)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // Asegurar columnas nuevas en estados_proceso si la tabla ya existía
    $checkCols = $conn->query("SHOW COLUMNS FROM estados_proceso LIKE 'estado_base_codigo'");
    if ($checkCols->num_rows == 0) {
        echo "   - Agregando columna estado_base_codigo...\n";
        $conn->query("ALTER TABLE estados_proceso ADD COLUMN estado_base_codigo VARCHAR(20) DEFAULT 'ABIERTO' AFTER color");
    }

    $checkCols = $conn->query("SHOW COLUMNS FROM estados_proceso LIKE 'bloquea_cierre'");
    if ($checkCols->num_rows == 0) {
        echo "   - Agregando columna bloquea_cierre...\n";
        $conn->query("ALTER TABLE estados_proceso ADD COLUMN bloquea_cierre BOOLEAN DEFAULT 0 AFTER estado_base_codigo");
    }

    // 4. Crear tabla transiciones_estado
    echo "4. ASEGURANDO TABLA transiciones_estado...\n";
    $conn->query("CREATE TABLE IF NOT EXISTS transiciones_estado (
        id INT AUTO_INCREMENT PRIMARY KEY,
        estado_origen_id INT NOT NULL,
        estado_destino_id INT NOT NULL,
        nombre VARCHAR(100),
        modulo VARCHAR(50) DEFAULT 'servicio',
        trigger_code VARCHAR(50) DEFAULT 'MANUAL',
        INDEX idx_origen (estado_origen_id),
        INDEX idx_destino (estado_destino_id),
        INDEX idx_modulo (modulo)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

    // Asegurar columnas en transiciones_estado
    $checkCols = $conn->query("SHOW COLUMNS FROM transiciones_estado LIKE 'modulo'");
    if ($checkCols->num_rows == 0) {
        echo "   - Agregando columna modulo...\n";
        $conn->query("ALTER TABLE transiciones_estado ADD COLUMN modulo VARCHAR(50) DEFAULT 'servicio' AFTER estado_destino_id");
    }

    $checkCols = $conn->query("SHOW COLUMNS FROM transiciones_estado LIKE 'trigger_code'");
    if ($checkCols->num_rows == 0) {
        echo "   - Agregando columna trigger_code...\n";
        $conn->query("ALTER TABLE transiciones_estado ADD COLUMN trigger_code VARCHAR(50) DEFAULT 'MANUAL' AFTER nombre");
    }

    $conn->commit();
    echo "\n✅ Sistema de Workflow reparado exitosamente.\n";

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
}

echo "</pre>";
echo "</body></html>";
?>