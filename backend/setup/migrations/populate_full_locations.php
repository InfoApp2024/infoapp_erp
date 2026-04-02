<?php
/**
 * populate_full_locations.php
 * Script para descargar y poblar TODOS los departamentos y municipios de Colombia
 * con soporte para la estructura legacy (columna departamento string).
 */

set_time_limit(300); // 5 minutos por si acaso
require_once __DIR__ . '/../../conexion.php';

echo "<html><body style='font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px;'>";
echo "<h2>--- Poblado de Ubicaciones (Colombia Full - Fix Legacy) ---</h2>";
echo "<pre style='background: #252526; padding: 15px; border-radius: 5px; border: 1px solid #3e3e42;'>";

try {
    // 1. Limpiar tablas actuales
    echo "1. LIMPIANDO TABLAS ACTUALES...\n";
    $conn->query("SET FOREIGN_KEY_CHECKS = 0");
    $conn->query("TRUNCATE TABLE ciudades");
    $conn->query("TRUNCATE TABLE departamentos");
    $conn->query("SET FOREIGN_KEY_CHECKS = 1");

    // 2. Obtener Departamentos
    echo "2. DESCARGANDO DEPARTAMENTOS...\n";
    $deptJson = file_get_contents("https://api-colombia.com/api/v1/Department");
    if (!$deptJson)
        throw new Exception("No se pudo conectar con la API de departamentos.");

    $departments = json_decode($deptJson, true);
    echo "   - Se encontraron " . count($departments) . " departamentos.\n";

    $deptMap = [];
    $stmtDept = $conn->prepare("INSERT INTO departamentos (id, nombre) VALUES (?, ?)");
    foreach ($departments as $dept) {
        $stmtDept->bind_param("is", $dept['id'], $dept['name']);
        $stmtDept->execute();
        $deptMap[$dept['id']] = $dept['name'];
    }
    echo "   ✅ Departamentos insertados.\n";

    // 3. Modificaciones de estructura para evitar errores legacy
    echo "3. AJUSTANDO ESTRUCTURA DE TABLA CIUDADES...\n";
    // Asegurar que departamento_id existe
    $checkCol = $conn->query("SHOW COLUMNS FROM ciudades LIKE 'departamento_id'");
    if ($checkCol->num_rows == 0) {
        $conn->query("ALTER TABLE ciudades ADD COLUMN departamento_id INT AFTER nombre");
    }
    // Hacer que la columna legacy 'departamento' sea opcional para evitar el error "no default value"
    $conn->query("ALTER TABLE ciudades MODIFY departamento VARCHAR(100) NULL");
    echo "   ✅ Estructura verificada.\n";

    // 4. Obtener Ciudades
    echo "4. DESCARGANDO CIUDADES (Municipios)...\n";
    $cityJson = file_get_contents("https://api-colombia.com/api/v1/City");
    if (!$cityJson)
        throw new Exception("No se pudo conectar con la API de ciudades.");

    $cities = json_decode($cityJson, true);
    echo "   - Se encontraron " . count($cities) . " municipios.\n";

    // Insertamos incluyendo la columna legacy 'departamento' para compatibilidad
    $stmtCity = $conn->prepare("INSERT INTO ciudades (id, nombre, departamento, departamento_id) VALUES (?, ?, ?, ?)");
    $count = 0;
    foreach ($cities as $city) {
        $deptName = isset($deptMap[$city['departmentId']]) ? $deptMap[$city['departmentId']] : 'Desconocido';
        $stmtCity->bind_param("issi", $city['id'], $city['name'], $deptName, $city['departmentId']);
        $stmtCity->execute();
        $count++;
        if ($count % 100 == 0)
            echo "   - Procesados $count municipios...\n";
    }
    echo "   ✅ $count municipios insertados con éxito.\n";

    echo "\n🚀 PROCESO COMPLETADO EXITOSAMENTE.";

} catch (Exception $e) {
    echo "\n❌ ERROR: " . $e->getMessage() . "\n";
    echo "Nota: Asegúrate de que tu servidor tenga acceso a internet (salida HTTPS).";
}

echo "</pre>";
echo "</body></html>";
?>