<?php
// backend/servicio/helpers/estado_helper.php
// Funciones helper para determinar si un estado es finalizado

/**
 * Determina si un estado es un estado final basado en su nombre
 * @param mysqli $conn Conexión a la base de datos
 * @param int $estado_id ID del estado a verificar
 * @return bool true si es un estado final, false en caso contrario
 */
function esEstadoFinal($conn, $estado_id)
{
    if (!$estado_id) {
        return false;
    }

    // ✅ ACTUALIZADO: Obtenemos también bloquea_cierre y estado_base_codigo
    $stmt = $conn->prepare("SELECT nombre_estado, bloquea_cierre, estado_base_codigo FROM estados_proceso WHERE id = ?");
    $stmt->bind_param("i", $estado_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $estado = $result->fetch_assoc();
    $stmt->close();

    if (!$estado) {
        return false;
    }

    // 1️⃣ PRIORIDAD MÁXIMA: Si el estado tiene el check de bloqueo activo, JAMÁS es final
    if (isset($estado['bloquea_cierre']) && (int) $estado['bloquea_cierre'] === 1) {
        return false;
    }

    $nombre_estado = strtoupper($estado['nombre_estado']);
    $estado_base = strtoupper($estado['estado_base_codigo'] ?? '');

    // 2️⃣ SEGUNDA PRIORIDAD: Si tiene un nombre o estado base que indique finalización
    $palabras_finalizacion = ['FINALIZADO', 'ENTREGADO', 'CERRADO', 'TERMINADO', 'COMPLETADO'];

    // Verificar en el nombre del estado
    foreach ($palabras_finalizacion as $palabra) {
        if (strpos($nombre_estado, $palabra) !== false) {
            return true;
        }
    }

    // Verificar en el código base (por si el nombre es personalizado pero el base es final)
    if (in_array($estado_base, ['FINALIZADO', 'ENTREGADO', 'CERRADO'])) {
        return true;
    }

    return false;
}

/**
 * Actualiza el campo es_finalizado de un servicio basado en su estado y anulación
 * @param mysqli $conn Conexión a la base de datos
 * @param int $servicio_id ID del servicio
 * @param int $estado_id ID del estado actual del servicio
 * @param bool $anulado Si el servicio está anulado
 * @return bool true si la actualización fue exitosa
 */
function actualizarEsFinalizadoServicio($conn, $servicio_id, $estado_id, $anulado = false)
{
    // Determinar si debe marcarse como finalizado
    $es_finalizado = $anulado || esEstadoFinal($conn, $estado_id);

    // Actualizar el campo
    $stmt = $conn->prepare("UPDATE servicios SET es_finalizado = ? WHERE id = ?");
    $es_finalizado_int = $es_finalizado ? 1 : 0;
    $stmt->bind_param("ii", $es_finalizado_int, $servicio_id);
    $resultado = $stmt->execute();
    $stmt->close();

    return $resultado;
}
?>