<?php
// backend/setup/diagnostico_completo.php
// Script para diagnosticar el estado actual de la base de datos y rendimiento

header("Content-Type: text/plain; charset=utf-8");

// Cargar configuración de base de datos
$config = require __DIR__ . '/db_config.php';

$conn = new mysqli(
    $config['servername'],
    $config['username'],
    $config['password'],
    $config['database']
);

if ($conn->connect_error) {
    die("Error de conexión: " . $conn->connect_error);
}

$conn->set_charset("utf8mb4");

echo "=== DIAGNÓSTICO COMPLETO DEL SISTEMA ===\n\n";

try {
    // ===== PASO 1: Verificar estructura de tabla =====
    echo "[1] ESTRUCTURA DE LA TABLA SERVICIOS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $checkColumn = $conn->query("SHOW COLUMNS FROM servicios LIKE 'es_finalizado'");

    if ($checkColumn->num_rows > 0) {
        echo "✅ Columna 'es_finalizado' EXISTE\n";
        $colInfo = $checkColumn->fetch_assoc();
        echo "   - Tipo: {$colInfo['Type']}\n";
        echo "   - Null: {$colInfo['Null']}\n";
        echo "   - Default: {$colInfo['Default']}\n\n";
    } else {
        echo "❌ Columna 'es_finalizado' NO EXISTE\n";
        echo "   ⚠️  PROBLEMA CRÍTICO: Debes ejecutar migrate_add_es_finalizado.php\n\n";
    }

    // ===== PASO 2: Verificar índices =====
    echo "[2] ÍNDICES EN LA TABLA SERVICIOS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $indexes = $conn->query("SHOW INDEX FROM servicios");
    $indexList = [];

    while ($row = $indexes->fetch_assoc()) {
        $keyName = $row['Key_name'];
        if (!isset($indexList[$keyName])) {
            $indexList[$keyName] = [];
        }
        $indexList[$keyName][] = $row['Column_name'];
    }

    foreach ($indexList as $indexName => $columns) {
        $colStr = implode(', ', $columns);
        echo "   - $indexName: ($colStr)\n";
    }

    // Verificar índices críticos
    $indicesCriticos = ['idx_es_finalizado', 'idx_finalizado_orden', 'idx_estado', 'idx_o_servicio'];
    echo "\n   Verificación de índices críticos:\n";
    foreach ($indicesCriticos as $idx) {
        if (isset($indexList[$idx])) {
            echo "   ✅ $idx\n";
        } else {
            echo "   ❌ $idx FALTANTE\n";
        }
    }
    echo "\n";

    // ===== PASO 3: Estadísticas de datos =====
    echo "[3] ESTADÍSTICAS DE DATOS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $stats = $conn->query("SELECT 
        COUNT(*) as total,
        SUM(CASE WHEN es_finalizado = 1 THEN 1 ELSE 0 END) as finalizados,
        SUM(CASE WHEN es_finalizado = 0 THEN 1 ELSE 0 END) as activos,
        SUM(CASE WHEN anular_servicio = 1 THEN 1 ELSE 0 END) as anulados
    FROM servicios");

    if ($stats) {
        $data = $stats->fetch_assoc();
        echo "   - Total servicios: {$data['total']}\n";
        echo "   - Finalizados (es_finalizado=1): {$data['finalizados']}\n";
        echo "   - Activos (es_finalizado=0): {$data['activos']}\n";
        echo "   - Anulados: {$data['anulados']}\n\n";

        if ($data['finalizados'] == 0 && $data['total'] > 0) {
            echo "   ⚠️  PROBLEMA: Todos los servicios tienen es_finalizado=0\n";
            echo "      Debes ejecutar migrate_populate_es_finalizado.php\n\n";
        }
    }

    // ===== PASO 4: Test de rendimiento - Solo Activos =====
    echo "[4] BENCHMARK - SOLO ACTIVOS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $sql = "SELECT COUNT(*) as total FROM servicios WHERE es_finalizado = 0";

    $start = microtime(true);
    $result = $conn->query($sql);
    $time = (microtime(true) - $start) * 1000;

    if ($result) {
        $count = $result->fetch_assoc()['total'];
        echo "   - Tiempo: " . number_format($time, 2) . " ms\n";
        echo "   - Registros: $count\n";

        if ($time > 100) {
            echo "   ⚠️  LENTO: Debería ser <100ms\n";
        } else {
            echo "   ✅ RÁPIDO\n";
        }
    }

    // EXPLAIN
    echo "\n   EXPLAIN:\n";
    $explain = $conn->query("EXPLAIN $sql");
    while ($row = $explain->fetch_assoc()) {
        echo "   - Tipo: {$row['type']}\n";
        echo "   - Posible key: {$row['possible_keys']}\n";
        echo "   - Key usado: {$row['key']}\n";
        echo "   - Rows: {$row['rows']}\n";
    }
    echo "\n";

    // ===== PASO 5: Test de rendimiento - Solo Finalizados =====
    echo "[5] BENCHMARK - SOLO FINALIZADOS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $sql = "SELECT COUNT(*) as total FROM servicios WHERE es_finalizado = 1";

    $start = microtime(true);
    $result = $conn->query($sql);
    $time = (microtime(true) - $start) * 1000;

    if ($result) {
        $count = $result->fetch_assoc()['total'];
        echo "   - Tiempo: " . number_format($time, 2) . " ms\n";
        echo "   - Registros: $count\n";

        if ($time > 100) {
            echo "   ⚠️  LENTO: Debería ser <100ms\n";
        } else {
            echo "   ✅ RÁPIDO\n";
        }
    }

    // EXPLAIN
    echo "\n   EXPLAIN:\n";
    $explain = $conn->query("EXPLAIN $sql");
    while ($row = $explain->fetch_assoc()) {
        echo "   - Tipo: {$row['type']}\n";
        echo "   - Posible key: {$row['possible_keys']}\n";
        echo "   - Key usado: {$row['key']}\n";
        echo "   - Rows: {$row['rows']}\n";
    }
    echo "\n";

    // ===== PASO 6: Test query completa con JOINs =====
    echo "[6] BENCHMARK - QUERY COMPLETA (con JOINs):\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $sql = "SELECT s.id, s.o_servicio, e.nombre_estado
            FROM servicios s
            LEFT JOIN estados_proceso e ON s.estado = e.id
            WHERE s.es_finalizado = 1
            ORDER BY s.o_servicio DESC
            LIMIT 20";

    $start = microtime(true);
    $result = $conn->query($sql);
    $time = (microtime(true) - $start) * 1000;

    echo "   - Tiempo: " . number_format($time, 2) . " ms\n";
    echo "   - Registros: " . ($result ? $result->num_rows : 0) . "\n";

    if ($time > 500) {
        echo "   ⚠️  LENTO: Debería ser <500ms\n";
    } else {
        echo "   ✅ RÁPIDO\n";
    }
    echo "\n";

    // ===== PASO 7: Verificar subconsultas =====
    echo "[7] ANÁLISIS DE SUBCONSULTAS:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    // Verificar índices en tablas relacionadas
    $tablasRelacionadas = ['notas', 'firmas', 'servicios_desbloqueos_repuestos'];

    foreach ($tablasRelacionadas as $tabla) {
        $checkTable = $conn->query("SHOW TABLES LIKE '$tabla'");
        if ($checkTable && $checkTable->num_rows > 0) {
            $indexes = $conn->query("SHOW INDEX FROM $tabla WHERE Column_name LIKE '%servicio%'");
            if ($indexes && $indexes->num_rows > 0) {
                echo "   ✅ $tabla tiene índice en servicio_id\n";
            } else {
                echo "   ⚠️  $tabla NO tiene índice en servicio_id\n";
            }
        }
    }
    echo "\n";

    // ===== PASO 8: Diagnóstico final =====
    echo "[8] DIAGNÓSTICO FINAL:\n";
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

    $problemas = [];

    if ($checkColumn->num_rows == 0) {
        $problemas[] = "❌ CRÍTICO: Columna es_finalizado no existe";
    }

    if (!isset($indexList['idx_es_finalizado'])) {
        $problemas[] = "❌ CRÍTICO: Falta índice idx_es_finalizado";
    }

    if (isset($data) && $data['finalizados'] == 0 && $data['total'] > 0) {
        $problemas[] = "❌ CRÍTICO: Datos no migrados (todos es_finalizado=0)";
    }

    if (empty($problemas)) {
        echo "   ✅ No se encontraron problemas críticos\n";
        echo "   ℹ️  Si aún es lento, el problema puede ser:\n";
        echo "      - Conexión de red lenta\n";
        echo "      - Servidor sobrecargado\n";
        echo "      - Subconsultas en listar_servicios.php\n";
    } else {
        echo "   PROBLEMAS ENCONTRADOS:\n";
        foreach ($problemas as $problema) {
            echo "   $problema\n";
        }
        echo "\n   SOLUCIÓN:\n";
        echo "   1. Ejecuta migrate_add_es_finalizado.php\n";
        echo "   2. Ejecuta migrate_populate_es_finalizado.php\n";
        echo "   3. Ejecuta verify_es_finalizado_integrity.php\n";
    }

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
}

$conn->close();
?>