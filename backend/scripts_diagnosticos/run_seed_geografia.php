<?php
// run_seed_geografia.php - Automates the insertion of all Colombian 
// Departments and Municipalities using official DIVIPOLA data.
// Includes schema update (adding 'codigo' column) and data cleanup.
require_once 'login/auth_middleware.php';

// Set high execution time for 1100+ records
set_time_limit(300);

try {
    require 'conexion.php';

    // 1. Schema Update: Add 'codigo' column to 'ciudades' if it doesn't exist
    $res = $conn->query("SHOW COLUMNS FROM ciudades LIKE 'codigo'");
    if ($res->num_rows == 0) {
        $conn->query("ALTER TABLE ciudades ADD COLUMN codigo VARCHAR(10) AFTER id");
    }

    // 2. Data Cleanup: Clear tables to ensure a fresh, duplicate-free start
    $conn->query("SET FOREIGN_KEY_CHECKS = 0");
    $conn->query("TRUNCATE TABLE ciudades");
    $conn->query("TRUNCATE TABLE departamentos");
    $conn->query("SET FOREIGN_KEY_CHECKS = 1");

    // 3. Fetch Official DIVIPOLA Data from datos.gov.co
    $apiUrl = "https://www.datos.gov.co/resource/gdxc-w37w.json?\$limit=2000";
    $json = file_get_contents($apiUrl);

    if ($json === false) {
        throw new Exception("Error al conectar con la API de Datos Abiertos Colombia.");
    }

    $data = json_decode($json, true);
    if (!is_array($data)) {
        throw new Exception("Error al procesar los datos de la API.");
    }

    // 4. Extract unique departments
    $deps = [];
    foreach ($data as $item) {
        $id = (int) $item['cod_dpto'];
        $nombre = strtoupper($item['dpto']);
        $deps[$id] = $nombre;
    }

    // 5. Insert Departments
    $stmtDep = $conn->prepare("INSERT INTO departamentos (id, nombre) VALUES (?, ?)");
    foreach ($deps as $id => $nombre) {
        $stmtDep->bind_param("is", $id, $nombre);
        $stmtDep->execute();
    }
    $stmtDep->close();

    // 6. Insert Municipalities with Code
    $stmtMpio = $conn->prepare("INSERT INTO ciudades (codigo, nombre, departamento, departamento_id) VALUES (?, ?, ?, ?)");
    $insertedCount = 0;
    foreach ($data as $item) {
        $codigo = $item['cod_mpio'];
        $nombre = strtoupper($item['nom_mpio']);
        $depto = strtoupper($item['dpto']);
        $deptoId = (int) $item['cod_dpto'];

        $stmtMpio->bind_param("sssi", $codigo, $nombre, $depto, $deptoId);
        if ($stmtMpio->execute()) {
            $insertedCount++;
        }
    }
    $stmtMpio->close();

    echo json_encode([
        "success" => true,
        "message" => "Geografía completa procesada exitosamente con códigos DIVIPOLA.",
        "details" => [
            "tablas_limpiadas" => ["ciudades", "departamentos"],
            "columna_codigo_asegurada" => true,
            "departamentos_insertados" => count($deps),
            "municipios_insertados" => $insertedCount
        ]
    ]);

} catch (Exception $e) {
    echo json_encode([
        "success" => false,
        "message" => $e->getMessage()
    ]);
}
