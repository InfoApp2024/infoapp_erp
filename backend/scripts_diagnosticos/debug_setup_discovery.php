<?php
header('Content-Type: text/plain; charset=UTF-8');
require 'conexion.php';

echo "--- COMPROBACIÓN DE DIRECTORIOS DE MÓDULOS ---\n\n";

$backend_root = realpath(__DIR__ . '/');
$modules = [
    'accounting',
    'chatbot',
    'clientes',
    'core',
    'especialidades',
    'firma',
    'geocercas',
    'impuestos',
    'inspecciones',
    'login',
    'notas',
    'servicio',
    'staff'
];

foreach ($modules as $m) {
    $dir = $backend_root . '/' . $m;
    $exists = is_dir($dir) ? "[OK]" : "[NO EXISTE]";
    $hasInit = file_exists($dir . '/init.sql') ? " (init.sql OK)" : " (SIN init.sql)";
    echo "$exists $m $hasInit\n";
}

echo "\n--- COMPROBACIÓN DE MIGRACIONES ---\n";
$migration_dir = $backend_root . '/migrations';
if (is_dir($migration_dir)) {
    $files = glob($migration_dir . '/*.sql');
    echo "Total archivos .sql en migrations: " . count($files) . "\n";
    if (count($files) > 0) {
        sort($files);
        echo "Primera migración: " . basename($files[0]) . "\n";
        echo "Última migración: " . basename(end($files)) . "\n";
    }
} else {
    echo "[ERROR] El directorio migrations/ no existe.\n";
}

echo "\n--- FIN DE LA COMPROBACIÓN ---\n";
?>