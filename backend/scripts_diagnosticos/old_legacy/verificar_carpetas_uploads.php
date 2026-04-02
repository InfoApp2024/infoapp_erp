<?php
require_once '../login/auth_middleware.php';
$currentUser = requireAuth();

// Verificar carpetas de uploads y sus permisos
header('Content-Type: text/html; charset=utf-8');

echo "<h2>🔍 Verificación de Carpetas de Upload</h2>";
echo "<p><strong>Timestamp:</strong> " . date('Y-m-d H:i:s') . "</p>";
echo "<hr>";

// Rutas a verificar
$carpetas = [
    '../uploads/' => 'Carpeta principal uploads',
    '../uploads/campos_adicionales/' => 'Carpeta campos adicionales',
    '../uploads/campos_adicionales/imagenes/' => 'Carpeta imágenes',
    '../uploads/campos_adicionales/archivos/' => 'Carpeta archivos',
];

echo "<h3>📁 Estado de Carpetas:</h3>";
echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
echo "<tr style='background-color: #f0f0f0;'>";
echo "<th>Ruta</th><th>Descripción</th><th>Existe</th><th>Permisos</th><th>Escribible</th><th>Acción</th>";
echo "</tr>";

foreach ($carpetas as $ruta => $descripcion) {
    $existe = is_dir($ruta);
    $permisos = $existe ? substr(sprintf('%o', fileperms($ruta)), -4) : 'N/A';
    $escribible = $existe && is_writable($ruta);
    
    $color_fila = $existe && $escribible ? '#e8f5e8' : '#ffe8e8';
    
    echo "<tr style='background-color: $color_fila;'>";
    echo "<td><code>$ruta</code></td>";
    echo "<td>$descripcion</td>";
    echo "<td>" . ($existe ? '✅ Sí' : '❌ No') . "</td>";
    echo "<td>$permisos</td>";
    echo "<td>" . ($escribible ? '✅ Sí' : '❌ No') . "</td>";
    echo "<td>";
    
    if (!$existe) {
        echo "<button onclick='crearCarpeta(\"$ruta\")'>Crear</button>";
    } elseif (!$escribible) {
        echo "<button onclick='cambiarPermisos(\"$ruta\")'>Fijar Permisos</button>";
    } else {
        echo "✅ OK";
    }
    
    echo "</td>";
    echo "</tr>";
}
echo "</table>";

echo "<hr>";

// Intentar crear carpetas faltantes automáticamente
echo "<h3>🛠️ Auto-corrección:</h3>";

foreach ($carpetas as $ruta => $descripcion) {
    if (!is_dir($ruta)) {
        echo "<p>🔧 Intentando crear: <code>$ruta</code>";
        
        if (mkdir($ruta, 0755, true)) {
            echo " ✅ <strong>Creada exitosamente</strong></p>";
        } else {
            echo " ❌ <strong>Error creando carpeta</strong></p>";
        }
    } else {
        echo "<p>✅ <code>$ruta</code> ya existe</p>";
    }
}

echo "<hr>";

// Verificar archivos existentes
echo "<h3>📋 Archivos Existentes:</h3>";

try {
    $pdo = new PDO("mysql:host=localhost;dbname=dev;charset=utf8mb4", "root", "");
    
    $stmt = $pdo->query("
        SELECT 
            nombre_almacenado, 
            ruta_archivo, 
            nombre_original,
            tamaño_bytes,
            fecha_subida
        FROM archivos_campos_adicionales 
        ORDER BY fecha_subida DESC 
        LIMIT 10
    ");
    $archivos_bd = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    if (empty($archivos_bd)) {
        echo "<p>⚠️ No hay archivos registrados en la BD</p>";
    } else {
        echo "<table border='1' style='border-collapse: collapse; width: 100%;'>";
        echo "<tr style='background-color: #f0f0f0;'>";
        echo "<th>Nombre BD</th><th>Ruta BD</th><th>Nombre Original</th><th>Existe Físicamente</th><th>Tamaño</th>";
        echo "</tr>";
        
        foreach ($archivos_bd as $archivo) {
            $ruta_fisica = '../' . $archivo['ruta_archivo'];
            $existe_fisicamente = file_exists($ruta_fisica);
            $tamaño_fisico = $existe_fisicamente ? filesize($ruta_fisica) : 0;
            
            $color = $existe_fisicamente ? '#e8f5e8' : '#ffe8e8';
            
            echo "<tr style='background-color: $color;'>";
            echo "<td>{$archivo['nombre_almacenado']}</td>";
            echo "<td><code>{$archivo['ruta_archivo']}</code></td>";
            echo "<td>{$archivo['nombre_original']}</td>";
            echo "<td>" . ($existe_fisicamente ? "✅ Sí ($tamaño_fisico bytes)" : "❌ No") . "</td>";
            echo "<td>{$archivo['tamaño_bytes']} bytes</td>";
            echo "</tr>";
        }
        echo "</table>";
        
        $archivos_faltantes = array_filter($archivos_bd, function($archivo) {
            return !file_exists('../' . $archivo['ruta_archivo']);
        });
        
        if (!empty($archivos_faltantes)) {
            echo "<p style='color: red;'>❌ <strong>" . count($archivos_faltantes) . " archivo(s) registrado(s) en BD pero NO existen físicamente</strong></p>";
        }
    }
    
} catch (Exception $e) {
    echo "<p style='color: red;'>❌ Error consultando BD: {$e->getMessage()}</p>";
}

echo "<hr>";

// Test de escritura
echo "<h3>🧪 Test de Escritura:</h3>";

$test_file = '../uploads/campos_adicionales/test_write.txt';
$test_content = 'Test de escritura: ' . date('Y-m-d H:i:s');

if (file_put_contents($test_file, $test_content)) {
    echo "<p style='color: green;'>✅ <strong>Test de escritura exitoso</strong></p>";
    echo "<p>Archivo creado: <code>$test_file</code></p>";
    
    // Limpiar archivo de test
    if (file_exists($test_file)) {
        unlink($test_file);
        echo "<p>🧹 Archivo de test eliminado</p>";
    }
} else {
    echo "<p style='color: red;'>❌ <strong>Error en test de escritura</strong></p>";
    echo "<p>No se pudo escribir en: <code>$test_file</code></p>";
}

?>

<script>
function crearCarpeta(ruta) {
    alert('Crear carpeta: ' + ruta + '\nEjecuta: mkdir -p ' + ruta + ' && chmod 755 ' + ruta);
}

function cambiarPermisos(ruta) {
    alert('Cambiar permisos: ' + ruta + '\nEjecuta: chmod 755 ' + ruta);
}
</script>

<style>
    body { font-family: Arial, sans-serif; margin: 20px; }
    table { margin: 10px 0; border-collapse: collapse; }
    th, td { padding: 8px; text-align: left; border: 1px solid #ddd; }
    th { background-color: #f0f0f0; }
    code { background-color: #f5f5f5; padding: 2px 4px; border-radius: 3px; }
    button { padding: 4px 8px; background-color: #007bff; color: white; border: none; border-radius: 3px; cursor: pointer; }
</style>