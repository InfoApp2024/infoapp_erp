<?php
// backend/servicio/helpers/trazabilidad_helper.php

class TrazabilidadHelper
{
    /**
     * Registra una transición de estado en la tabla de logs y calcula la duración del estado anterior.
     * 
     * @param mysqli $conn Conexión a la BD
     * @param int $servicio_id ID del servicio
     * @param int $estado_destino_id ID del nuevo estado
     * @param int $usuario_id ID del usuario que realiza el cambio
     * @return bool
     */
    public static function registrarTransicionEstado($conn, $servicio_id, $estado_destino_id, $usuario_id)
    {
        $now = date('Y-m-d H:i:s');

        // 1. Obtener el último log registrado para este servicio
        $stmt = $conn->prepare("
            SELECT id, timestamp 
            FROM servicios_logs 
            WHERE servicio_id = ? 
            ORDER BY timestamp DESC, id DESC 
            LIMIT 1
        ");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $last_log = $result->fetch_assoc();
        $stmt->close();

        $from_status_id = null;
        if ($last_log) {
            // Calcular duración del estado anterior
            $last_time = strtotime($last_log['timestamp']);
            $current_time = strtotime($now);
            $duration = max(0, $current_time - $last_time);

            // Actualizar el log anterior con la duración calculada
            $update_stmt = $conn->prepare("UPDATE servicios_logs SET duration_seconds = ? WHERE id = ?");
            $update_stmt->bind_param("ii", $duration, $last_log['id']);
            $update_stmt->execute();
            $update_stmt->close();

            // El estado anterior es el to_status del log anterior
            $stmt_prev = $conn->prepare("SELECT to_status_id FROM servicios_logs WHERE id = ?");
            $stmt_prev->bind_param("i", $last_log['id']);
            $stmt_prev->execute();
            $prev_data = $stmt_prev->get_result()->fetch_assoc();
            $from_status_id = $prev_data['to_status_id'] ?? null;
            $stmt_prev->close();
        }

        // 2. Insertar el nuevo log del estado actual
        $insert_stmt = $conn->prepare("
            INSERT INTO servicios_logs (servicio_id, from_status_id, to_status_id, user_id, timestamp) 
            VALUES (?, ?, ?, ?, ?)
        ");
        $insert_stmt->bind_param("iiiis", $servicio_id, $from_status_id, $estado_destino_id, $usuario_id, $now);
        $success = $insert_stmt->execute();
        $insert_stmt->close();

        return $success;
    }
}
?>