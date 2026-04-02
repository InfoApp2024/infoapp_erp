<?php
// backend/run_migrations_tributaria.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once '../../conexion.php';

echo "Iniciando migraciones tributarias...\n";

// 1. Crear tabla impuestos_config
echo "1. Procesando tabla impuestos_config...\n";
$sqlImpuestos = file_get_contents(__DIR__ . '/impuestos/init.sql');
if ($conn->multi_query($sqlImpuestos)) {
    do {
        // Consumir resultados para liberar el buffer
        if ($res = $conn->store_result())
            $res->free();
    } while ($conn->more_results() && $conn->next_result());
    echo "✅ Tabla impuestos_config procesada correctamente.\n";
} else {
    echo "❌ Error creando tabla impuestos_config: " . $conn->error . "\n";
}

// 2. Alterar tabla clientes
echo "2. Verificando columnas en tabla clientes...\n";
$columnas = ['regimen_tributario', 'codigo_ciiu', 'es_agente_retenedor'];
$columnasFaltantes = [];

foreach ($columnas as $col) {
    $check = $conn->query("SHOW COLUMNS FROM clientes LIKE '$col'");
    if ($check->num_rows == 0) {
        $columnasFaltantes[] = $col;
    }
}

if (empty($columnasFaltantes)) {
    echo "✅ Todas las columnas tributarias ya existen en clientes.\n";
} else {
    echo "⚠️ Faltan columnas: " . implode(', ', $columnasFaltantes) . ". Aplicando cambios...\n";

    // Leemos el SQL pero mejor construimos la query dinámica o ejecutamos linea por linea si es simple
    // Como tengo el archivo, intentaré leerlo, pero para ser seguro con errores parciales,
    // voy a ejecutar las alteraciones una por una basándome en lo que falta.

    // Simplemente ejecutamos el SQL de migración y atrapamos errores si algo falla
    $sqlClientes = file_get_contents(__DIR__ . '/clientes/migration_tributaria.sql');

    // Limpieza básica de comentarios para evitar problemas con multi_query a veces
    // Pero multi_query suele manejarlo bien.

    if ($conn->multi_query($sqlClientes)) {
        do {
            if ($res = $conn->store_result())
                $res->free();
        } while ($conn->more_results() && $conn->next_result());
        echo "✅ Tabla clientes actualizada correctamente.\n";
    } else {
        echo "❌ Error actualizando tabla clientes: " . $conn->error . "\n";
    }
}

$conn->close();
echo "🏁 Migración finalizada.\n";
?>