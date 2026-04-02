<?php
// migration_v6_service_operations.php
error_reporting(E_ALL);
ini_set('display_errors', 1);

if (file_exists(__DIR__ . '/../conexion.php')) {
    require_once __DIR__ . '/../conexion.php';
} else if (file_exists(__DIR__ . '/conexion.php')) {
    require_once __DIR__ . '/conexion.php';
} else {
    die("❌ ERROR: No se pudo encontrar 'conexion.php'.\n");
}

try {
    echo "Iniciando migración v6 (Operaciones de Servicio)...\n";

    // 1. Crear tabla operaciones
    $create_table = "CREATE TABLE IF NOT EXISTS operaciones (
      id INT AUTO_INCREMENT PRIMARY KEY,
      servicio_id INT NOT NULL,
      descripcion TEXT NOT NULL,
      fecha_inicio DATETIME NULL,
      fecha_fin DATETIME NULL,
      tecnico_responsable_id INT NULL,
      observaciones TEXT NULL,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
      INDEX idx_servicio_id (servicio_id),
      FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE,
      FOREIGN KEY (tecnico_responsable_id) REFERENCES usuarios(id) ON DELETE SET NULL
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4";

    if ($conn->query($create_table) === TRUE) {
        echo "✅ Tabla 'operaciones' creada o ya existía.\n";
    } else {
        throw new Exception("Error al crear tabla operaciones: " . $conn->error);
    }

    // 2. Añadir operacion_id a servicio_repuestos
    $check_repuestos = $conn->query("SHOW COLUMNS FROM servicio_repuestos LIKE 'operacion_id'");
    if ($check_repuestos->num_rows == 0) {
        echo "Añadiendo columna 'operacion_id' a 'servicio_repuestos'...\n";
        $sql = "ALTER TABLE servicio_repuestos ADD COLUMN operacion_id INT NULL AFTER servicio_id";
        if ($conn->query($sql) === TRUE) {
            echo "✅ Columna 'operacion_id' añadida a 'servicio_repuestos'.\n";
            $conn->query("ALTER TABLE servicio_repuestos ADD INDEX idx_operacion_id (operacion_id)");
            $conn->query("ALTER TABLE servicio_repuestos ADD FOREIGN KEY (operacion_id) REFERENCES operaciones(id) ON DELETE SET NULL");
        } else {
            echo "❌ Error al añadir columna a servicio_repuestos: " . $conn->error . "\n";
        }
    } else {
        echo "ℹ️ La columna 'operacion_id' ya existe en 'servicio_repuestos'.\n";
    }

    // 3. Añadir operacion_id a servicio_staff
    $check_staff = $conn->query("SHOW COLUMNS FROM servicio_staff LIKE 'operacion_id'");
    if ($check_staff->num_rows == 0) {
        echo "Añadiendo columna 'operacion_id' a 'servicio_staff'...\n";
        $sql = "ALTER TABLE servicio_staff ADD COLUMN operacion_id INT NULL AFTER servicio_id";
        if ($conn->query($sql) === TRUE) {
            echo "✅ Columna 'operacion_id' añadida a 'servicio_staff'.\n";
            $conn->query("ALTER TABLE servicio_staff ADD INDEX idx_operacion_id (operacion_id)");
            $conn->query("ALTER TABLE servicio_staff ADD FOREIGN KEY (operacion_id) REFERENCES operaciones(id) ON DELETE SET NULL");
        } else {
            echo "❌ Error al añadir columna a servicio_staff: " . $conn->error . "\n";
        }
    } else {
        echo "ℹ️ La columna 'operacion_id' ya existe en 'servicio_staff'.\n";
    }

    echo "✅ Migración completada con éxito.\n";

} catch (Exception $e) {
    echo "❌ ERROR: " . $e->getMessage() . "\n";
}
?>