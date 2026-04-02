<?php
// backend/servicio/verificar_version.php
// Script para verificar qué versión de listar_servicios.php está activa

header("Content-Type: text/plain; charset=utf-8");

echo "=== VERIFICACIÓN DE VERSIÓN DE LISTAR_SERVICIOS.PHP ===\n\n";

$archivo = __DIR__ . '/listar_servicios.php';

if (!file_exists($archivo)) {
    echo "❌ ERROR: Archivo no encontrado\n";
    exit(1);
}

echo "[1] INFORMACIÓN DEL ARCHIVO:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";
echo "   - Ruta: $archivo\n";
echo "   - Tamaño: " . filesize($archivo) . " bytes\n";
echo "   - Última modificación: " . date("Y-m-d H:i:s", filemtime($archivo)) . "\n\n";

echo "[2] VERIFICACIÓN DE OPTIMIZACIONES:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

$contenido = file_get_contents($archivo);

// Test 1: Verificar si usa es_finalizado
if (strpos($contenido, 's.es_finalizado') !== false) {
    echo "   ✅ Usa columna es_finalizado\n";
} else {
    echo "   ❌ NO usa columna es_finalizado (versión antigua)\n";
}

// Test 2: Verificar si tiene subconsultas correlacionadas (MALO)
if (strpos($contenido, '(SELECT COUNT(*) FROM notas WHERE notas.id_servicio = s.id)') !== false) {
    echo "   ❌ TIENE subconsultas correlacionadas (LENTO)\n";
} else {
    echo "   ✅ NO tiene subconsultas correlacionadas\n";
}

// Test 3: Verificar si usa LEFT JOIN optimizado (BUENO)
if (strpos($contenido, 'notas_count.cantidad') !== false) {
    echo "   ✅ Usa LEFT JOIN optimizado para notas\n";
} else {
    echo "   ❌ NO usa LEFT JOIN optimizado\n";
}

if (strpos($contenido, 'firmas_count.cantidad') !== false) {
    echo "   ✅ Usa LEFT JOIN optimizado para firmas\n";
} else {
    echo "   ❌ NO usa LEFT JOIN optimizado\n";
}

if (strpos($contenido, 'desbloqueos_count.cantidad') !== false) {
    echo "   ✅ Usa LEFT JOIN optimizado para desbloqueos\n";
} else {
    echo "   ❌ NO usa LEFT JOIN optimizado\n";
}

echo "\n[3] BÚSQUEDA DE PATRONES PROBLEMÁTICOS:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

// Buscar LIKE queries
$countLike = substr_count($contenido, "LIKE '%FINALIZADO%'");
if ($countLike > 0) {
    echo "   ⚠️  Encontradas $countLike queries LIKE para FINALIZADO\n";
} else {
    echo "   ✅ No hay queries LIKE para estados finalizados\n";
}

// Buscar subconsultas SELECT en SELECT
$countSubqueries = substr_count($contenido, '(SELECT COUNT(*)');
if ($countSubqueries > 0) {
    echo "   ⚠️  Encontradas $countSubqueries subconsultas correlacionadas\n";
} else {
    echo "   ✅ No hay subconsultas correlacionadas\n";
}

echo "\n[4] LÍNEAS CLAVE DEL CÓDIGO:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

$lineas = explode("\n", $contenido);
$lineNumber = 0;

foreach ($lineas as $linea) {
    $lineNumber++;

    // Mostrar líneas relevantes
    if (
        stripos($linea, 'es_finalizado') !== false &&
        stripos($linea, 'WHERE') !== false
    ) {
        echo "   Línea $lineNumber: " . trim($linea) . "\n";
    }

    if (
        stripos($linea, 'notas_count') !== false ||
        stripos($linea, 'firmas_count') !== false ||
        stripos($linea, 'desbloqueos_count') !== false
    ) {
        if (
            stripos($linea, 'SELECT') !== false ||
            stripos($linea, 'LEFT JOIN') !== false
        ) {
            echo "   Línea $lineNumber: " . trim($linea) . "\n";
        }
    }
}

echo "\n[5] DIAGNÓSTICO FINAL:\n";
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n";

$esVersionOptimizada = (
    strpos($contenido, 's.es_finalizado') !== false &&
    strpos($contenido, 'notas_count.cantidad') !== false &&
    strpos($contenido, '(SELECT COUNT(*) FROM notas WHERE notas.id_servicio = s.id)') === false
);

if ($esVersionOptimizada) {
    echo "   ✅ VERSIÓN OPTIMIZADA DETECTADA\n";
    echo "   ℹ️  El archivo tiene todas las optimizaciones aplicadas.\n";
    echo "   ℹ️  Si aún es lento, el problema está en otro lado:\n";
    echo "      - Caché del navegador/app\n";
    echo "      - Latencia de red\n";
    echo "      - Procesamiento en Flutter\n";
} else {
    echo "   ❌ VERSIÓN ANTIGUA DETECTADA\n";
    echo "   ⚠️  ACCIÓN REQUERIDA: Sube el archivo actualizado al servidor\n";
}

echo "\n✅ VERIFICACIÓN COMPLETADA\n";
?>