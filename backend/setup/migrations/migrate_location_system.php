<?php
/**
 * migrate_location_system.php
 * Crea tabla departamentos y estructura ciudades de forma jerárquica.
 */

require_once __DIR__ . '/../../conexion.php';

// Asegurar que la salida se vea correctamente en el navegador
echo "<html><body style='font-family: monospace; background: #1e1e1e; color: #d4d4d4; padding: 20px;'>";
echo "<h2>--- Iniciando migración del sistema de ubicaciones ---</h2>";
echo "<pre style='background: #252526; padding: 15px; border-radius: 5px; border: 1px solid #3e3e42;'>";

try {
    $conn->begin_transaction();

    // 1. Crear tabla departamentos
    echo "1. CREATING TABLE departamentos...\n";
    $sqlDept = "CREATE TABLE IF NOT EXISTS departamentos (
        id INT PRIMARY KEY,
        nombre VARCHAR(100) NOT NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci";
    $conn->query($sqlDept);

    // 2. Poblar departamentos (DANE Codes)
    echo "2. POPULATING departamentos...\n";
    $depts = [
        [5, 'Antioquia'],
        [8, 'Atlántico'],
        [11, 'Bogotá D.C.'],
        [13, 'Bolívar'],
        [15, 'Boyacá'],
        [17, 'Caldas'],
        [18, 'Caquetá'],
        [19, 'Cauca'],
        [20, 'Cesar'],
        [23, 'Córdoba'],
        [25, 'Cundinamarca'],
        [27, 'Chocó'],
        [41, 'Huila'],
        [44, 'La Guajira'],
        [47, 'Magdalena'],
        [50, 'Meta'],
        [52, 'Nariño'],
        [54, 'Norte de Santander'],
        [63, 'Quindío'],
        [66, 'Risaralda'],
        [68, 'Santander'],
        [70, 'Sucre'],
        [73, 'Tolima'],
        [76, 'Valle del Cauca'],
        [81, 'Arauca'],
        [85, 'Casanare'],
        [86, 'Putumayo'],
        [88, 'San Andrés'],
        [91, 'Amazonas'],
        [94, 'Guainía'],
        [95, 'Guaviare'],
        [97, 'Vaupés'],
        [99, 'Vichada']
    ];

    $stmtDept = $conn->prepare("INSERT IGNORE INTO departamentos (id, nombre) VALUES (?, ?)");
    foreach ($depts as $d) {
        $stmtDept->bind_param("is", $d[0], $d[1]);
        $stmtDept->execute();
    }

    // 3. Modificar tabla ciudades para incluir departamento_id
    echo "3. UPDATING TABLE ciudades...\n";
    $checkCol = $conn->query("SHOW COLUMNS FROM ciudades LIKE 'departamento_id'");
    if ($checkCol->num_rows == 0) {
        $conn->query("ALTER TABLE ciudades ADD COLUMN departamento_id INT AFTER nombre");
    }

    // 4. Poblar ciudades principales (DANE Codes)
    echo "4. POPULATING ciudades...\n";
    $cities = [
        [11001, 'Bogotá', 11],
        [5001, 'Medellín', 5],
        [76001, 'Cali', 76],
        [8001, 'Barranquilla', 8],
        [13001, 'Cartagena', 13],
        [68001, 'Bucaramanga', 68],
        [66001, 'Pereira', 66],
        [17001, 'Manizales', 17],
        [73001, 'Ibagué', 73],
        [41001, 'Neiva', 41],
        [52001, 'Pasto', 52],
        [54001, 'Cúcuta', 54],
        [50001, 'Villavicencio', 50],
        [47001, 'Santa Marta', 47],
        [20001, 'Valledupar', 20],
        [23001, 'Montería', 23],
        [70001, 'Sincelejo', 70],
        [44001, 'Riohacha', 44],
        [19001, 'Popayán', 19],
        [15001, 'Tunja', 15],
        [27001, 'Quibdó', 27],
        [18001, 'Florencia', 18],
        [85001, 'Yopal', 85],
        [86001, 'Mocoa', 86],
        [81001, 'Arauca', 81],
        [95001, 'San José del Guaviare', 95],
        [99001, 'Puerto Carreño', 99],
        [94001, 'Inírida', 94],
        [97001, 'Mitú', 97],
        [91001, 'Leticia', 91],
        [88001, 'San Andrés', 88]
    ];

    foreach ($cities as $c) {
        $stmtCityIdx = $conn->prepare("INSERT IGNORE INTO ciudades (id, nombre, departamento_id) VALUES (?, ?, ?)");
        $stmtCityIdx->bind_param("isi", $c[0], $c[1], $c[2]);
        $stmtCityIdx->execute();
    }

    // Intentar vincular registros existentes que no tengan depto_id pero coincidan en nombre de depto
    echo "5. LINKING existing records by department name...\n";
    $conn->query("UPDATE ciudades c 
                  JOIN departamentos d ON LOWER(c.departamento) = LOWER(d.nombre) 
                  SET c.departamento_id = d.id 
                  WHERE c.departamento_id IS NULL");

    $conn->commit();
    echo "✅ Migración completada exitosamente.\n";

} catch (Exception $e) {
    if (isset($conn))
        $conn->rollback();
    echo "❌ ERROR: " . $e->getMessage() . "\n";
}

echo "</pre>";
echo "</body></html>";
?>