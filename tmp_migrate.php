<?php
require_once __DIR__ . '/../conexion.php';

$migration = [
    "CREATE TABLE IF NOT EXISTS fac_auditoria_ia_logs (
        id            INT AUTO_INCREMENT PRIMARY KEY,
        servicio_id   INT NOT NULL,
        ciclo         INT NOT NULL DEFAULT 1,
        analisis_text TEXT NOT NULL,
        fuente        VARCHAR(255) NULL,
        created_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        INDEX idx_servicio_ciclo (servicio_id, ciclo),
        CONSTRAINT fk_ia_logs_servicio FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci",
    
    "ALTER TABLE fac_auditorias_servicio ADD COLUMN IF NOT EXISTS es_excepcion TINYINT(1) NOT NULL DEFAULT 0",
    
    "CREATE TABLE IF NOT EXISTS fac_audit_ciclos (
        id           INT AUTO_INCREMENT PRIMARY KEY,
        servicio_id  INT NOT NULL,
        ciclo_actual INT NOT NULL DEFAULT 1,
        updated_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uk_servicio (servicio_id),
        CONSTRAINT fk_ciclo_servicio_v22 FOREIGN KEY (servicio_id) REFERENCES servicios(id) ON DELETE CASCADE
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci"
];

foreach ($migration as $sql) {
    if ($conn->query($sql) === TRUE) {
        echo "OK: $sql\n";
    } else {
        echo "ERROR: " . $conn->error . "\n";
    }
}
?>
