<?php
// backend/inspecciones/helpers/inspeccion_helper.php

/**
 * Determina si un estado es final para el módulo de inspecciones
 */
function esEstadoFinalInspeccion($conn, $estado_id)
{
    if (!$estado_id)
        return false;

    // 1. Obtener el módulo del estado actual
    $stmt = $conn->prepare("SELECT modulo FROM estados_proceso WHERE id = ?");
    $stmt->bind_param("i", $estado_id);
    $stmt->execute();
    $result = $stmt->get_result();
    $estado = $result->fetch_assoc();
    $stmt->close();

    if (!$estado)
        return false;

    $modulo = $estado['modulo'];

    // 2. Verificar si es el ID más alto para ese módulo
    $stmt_max = $conn->prepare("SELECT MAX(id) as max_id FROM estados_proceso WHERE modulo = ?");
    $stmt_max->bind_param("s", $modulo);
    $stmt_max->execute();
    $max_id = $stmt_max->get_result()->fetch_assoc()['max_id'];
    $stmt_max->close();

    return $estado_id == $max_id;
}

/**
 * Cuenta cuántas actividades quedan sin gestionar (sin servicio y no eliminadas)
 */
function contarActividadesPendientes($conn, $inspeccion_id)
{
    $sql = "SELECT COUNT(*) as pendientes 
            FROM inspecciones_actividades 
            WHERE inspeccion_id = ? AND deleted_at IS NULL AND servicio_id IS NULL";

    $stmt = $conn->prepare($sql);
    $stmt->bind_param("i", $inspeccion_id);
    $stmt->execute();
    $res = $stmt->get_result();
    $pendientes = $res->fetch_assoc()['pendientes'] ?? 0;
    $stmt->close();

    return (int) $pendientes;
}

/**
 * Verifica si quedan actividades pendientes y mueve a estado final si no hay ninguna
 */
function verificarYFinalizarInspeccion($conn, $inspeccion_id, $usuario_id)
{
    // 1. Usar el nuevo helper para contar pendientes
    $pendientes = contarActividadesPendientes($conn, $inspeccion_id);

    if ($pendientes == 0) {
        // 2. No hay pendientes, buscar el mejor estado final posible (el último creado por convención)

        // Primero intentamos obtener el módulo del estado actual de la inspección
        $modulo_actual = 'inspecciones';
        $stmt_mod = $conn->prepare("SELECT modulo FROM estados_proceso WHERE id = (SELECT estado_id FROM inspecciones WHERE id = ?)");
        $stmt_mod->bind_param("i", $inspeccion_id);
        if ($stmt_mod->execute()) {
            $res_mod = $stmt_mod->get_result();
            if ($row_mod = $res_mod->fetch_assoc()) {
                $modulo_actual = $row_mod['modulo'];
            }
        }
        $stmt_mod->close();

        // Buscamos el estado con mayor ID que coincida con el módulo actual
        $sql_final = "SELECT id FROM estados_proceso 
                      WHERE modulo = ?
                      ORDER BY id DESC LIMIT 1";

        $stmt_final = $conn->prepare($sql_final);
        $stmt_final->bind_param("s", $modulo_actual);
        $stmt_final->execute();
        $res_final = $stmt_final->get_result();

        if ($res_final && $res_final->num_rows > 0) {
            $estado_final_id = $res_final->fetch_assoc()['id'];

            // 3. Actualizar la inspección
            $sql_update = "UPDATE inspecciones SET estado_id = ?, updated_by = ? WHERE id = ?";
            $stmt_upd = $conn->prepare($sql_update);
            $stmt_upd->bind_param("iii", $estado_final_id, $usuario_id, $inspeccion_id);
            $stmt_upd->execute();
            $stmt_upd->close();

            return [
                'finalizada' => true,
                'nuevo_estado_id' => $estado_final_id
            ];
        }
    }

    return ['finalizada' => false];
}
?>