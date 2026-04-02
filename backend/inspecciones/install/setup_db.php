<?php
// backend/inspecciones/install/setup_db.php
// Script de utilidad para instalar/reparar la base de datos del módulo de inspecciones

header('Content-Type: text/html; charset=utf-8');
require_once '../../conexion.php'; // Ajusta la ruta si es necesario

echo "<h1>Instalación de Base de Datos - Inspecciones</h1>";

function ejecutarSQL($conn, $sql, $mensaje)
{
    try {
        if ($conn->query($sql) === TRUE) {
            echo "<p style='color: green;'>✅ $mensaje - OK</p>";
        } else {
            // Ignorar error si es "Tabla ya existe" o "Columna ya existe" para no alarmar
            if (strpos($conn->error, "already exists") !== false) {
                echo "<p style='color: orange;'>⚠️ $mensaje - Ya existe</p>";
            } else {
                throw new Exception($conn->error);
            }
        }
    } catch (Exception $e) {
        echo "<p style='color: red;'>❌ $mensaje - Error: " . $e->getMessage() . "</p>";
    }
}

// 1. Crear tabla principal
$sql_tabla_inspecciones = "
CREATE TABLE IF NOT EXISTS inspecciones (
    id INT AUTO_INCREMENT PRIMARY KEY,
    o_inspe VARCHAR(20) UNIQUE, 
    estado_id INT NOT NULL,
    sitio VARCHAR(100),
    fecha_inspe DATE,
    equipo_id INT NOT NULL,
    observacion TEXT,
    created_by INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_by INT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (estado_id) REFERENCES estados(id),
    FOREIGN KEY (equipo_id) REFERENCES equipos(id),
    FOREIGN KEY (created_by) REFERENCES usuarios(id),
    FOREIGN KEY (updated_by) REFERENCES usuarios(id)
)";
ejecutarSQL($conn, $sql_tabla_inspecciones, "Creando tabla 'inspecciones'");

// 2. Crear tabla inspectores
$sql_tabla_inspectores = "
CREATE TABLE IF NOT EXISTS inspecciones_inspectores (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    usuario_id INT NOT NULL, 
    rol_inspector VARCHAR(50) DEFAULT 'Principal',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (usuario_id) REFERENCES usuarios(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_inspector (inspeccion_id, usuario_id)
)";
ejecutarSQL($conn, $sql_tabla_inspectores, "Creando tabla 'inspecciones_inspectores'");

// 3. Crear tabla sistemas intermedio
$sql_tabla_sistemas = "
CREATE TABLE IF NOT EXISTS inspecciones_sistemas (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    sistema_id INT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (sistema_id) REFERENCES sistemas(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_sistema (inspeccion_id, sistema_id)
)";
ejecutarSQL($conn, $sql_tabla_sistemas, "Creando tabla 'inspecciones_sistemas'");

// 4. Crear tabla actividades intermedio
$sql_tabla_actividades = "
CREATE TABLE IF NOT EXISTS inspecciones_actividades (
    id INT AUTO_INCREMENT PRIMARY KEY,
    inspeccion_id INT NOT NULL,
    actividad_id INT NOT NULL,
    estado ENUM('Pendiente', 'En Proceso', 'Completada', 'Omitida') DEFAULT 'Pendiente',
    observaciones TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (inspeccion_id) REFERENCES inspecciones(id) ON DELETE CASCADE,
    FOREIGN KEY (actividad_id) REFERENCES actividades_estandar(id) ON DELETE CASCADE,
    UNIQUE KEY unique_inspeccion_actividad (inspeccion_id, actividad_id)
)";
ejecutarSQL($conn, $sql_tabla_actividades, "Creando tabla 'inspecciones_actividades'");

// 5. Configurar Trigger
// Primero eliminamos si existe para evitar conflictos
$conn->query("DROP TRIGGER IF EXISTS before_insert_inspecciones");

$sql_trigger = "
CREATE TRIGGER before_insert_inspecciones
BEFORE INSERT ON inspecciones
FOR EACH ROW
BEGIN
    DECLARE next_id INT;
    DECLARE year_month VARCHAR(6);
    
    SET year_month = DATE_FORMAT(NEW.fecha_inspe, '%Y%m');
    
    -- Simulacion de secuencia
    SET next_id = (SELECT COUNT(*) FROM inspecciones WHERE DATE_FORMAT(fecha_inspe, '%Y%m') = year_month) + 1;
    
    SET NEW.o_inspe = CONCAT('INS-', year_month, '-', LPAD(next_id, 4, '0'));
END
";

// Importante: mysqli::query no soporta DELIMITER, pero soporta crear triggers si se envía la sentencia completa
// siempre que no haya conflictos de parser. En PHP suele funcionar directo sin DELIMITER.
ejecutarSQL($conn, $sql_trigger, "Creando Trigger 'before_insert_inspecciones'");

echo "<br><hr><h3>Proceso Finalizado. Intenta crear una inspección nuevamente.</h3>";
$conn->close();
?>