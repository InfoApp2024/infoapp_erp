<?php
// backend/workflow/workflow_helper.php

class WorkflowHelper
{
    /**
     * Evalúa todos los disparadores posibles para un servicio y ejecuta el primero que sea válido.
     */
    public static function evaluarTriggersAutomaticos($conn, $servicio_id, $usuario_id = null)
    {
        error_log("WORKFLOW DEBUG: Evaluando triggers automáticos para servicio #$servicio_id");
        // Lista de disparadores relacionados con la edición del servicio
        $posibles_triggers = ['FOTO_SUBIDA', 'OS_REPUESTOS', 'FIRMA_CLIENTE', 'ASIGNAR_PERSONAL'];

        // Obtener flags de confirmación del servicio
        $stmt = $conn->prepare("SELECT suministraron_repuestos, fotos_confirmadas, firma_confirmada, personal_confirmado FROM servicios WHERE id = ?");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $flags = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$flags) {
            error_log("WORKFLOW ERROR: No se pudieron obtener los flags para el servicio #$servicio_id");
            return ['success' => false, 'message' => 'Servicio no encontrado'];
        }

        foreach ($posibles_triggers as $trigger_code) {
            // Verificar si el trigger ha sido confirmado por el usuario
            $confirmado = false;

            if ($trigger_code === 'OS_REPUESTOS') {
                $confirmado = (int) $flags['suministraron_repuestos'] === 1;
                if (!$confirmado)
                    error_log("WORKFLOW DEBUG: Saltando OS_REPUESTOS (no confirmado)");
            } elseif ($trigger_code === 'FOTO_SUBIDA') {
                $confirmado = (int) $flags['fotos_confirmadas'] === 1;
                if (!$confirmado)
                    error_log("WORKFLOW DEBUG: Saltando FOTO_SUBIDA (no confirmado)");
            } elseif ($trigger_code === 'FIRMA_CLIENTE') {
                $confirmado = (int) $flags['firma_confirmada'] === 1;
                if (!$confirmado)
                    error_log("WORKFLOW DEBUG: Saltando FIRMA_CLIENTE (no confirmado)");
            } elseif ($trigger_code === 'ASIGNAR_PERSONAL') {
                $confirmado = (int) $flags['personal_confirmado'] === 1;
                if (!$confirmado)
                    error_log("WORKFLOW DEBUG: Saltando ASIGNAR_PERSONAL (no confirmado)");
            }

            if (!$confirmado) {
                continue;
            }

            error_log("WORKFLOW DEBUG: Intentando disparar trigger: $trigger_code");
            $resultado = self::ejecutarTrigger($conn, $servicio_id, $trigger_code, $usuario_id);
            error_log("WORKFLOW DEBUG: Resultado de $trigger_code: " . json_encode($resultado));

            if ($resultado['success'] && isset($resultado['new_state'])) {
                return $resultado; // Retornamos el primer cambio exitoso
            }
        }

        error_log("WORKFLOW DEBUG: Fin evaluación. No se aplicaron transiciones.");
        return ['success' => true, 'message' => 'No se ejecutaron transiciones automáticas'];
    }

    /**
     * Intenta ejecutar una transición automática para un servicio basada en un disparador.
     * 
     * @param mysqli $conn Conexión a la BD
     * @param int $servicio_id ID del servicio
     * @param string $trigger_code Código del disparador (ej: FOTO_SUBIDA, FIRMA_CLIENTE)
     * @param int|null $usuario_id ID del usuario que provoca la acción (opcional)
     * @return array Resultado de la operación ['success' => bool, 'message' => string, 'new_state' => int|null]
     */
    public static function ejecutarTrigger($conn, $servicio_id, $trigger_code, $usuario_id = null)
    {
        try {
            $conn->begin_transaction();

            // 1. Obtener estado actual del servicio
            $stmt = $conn->prepare("SELECT estado, responsable_id FROM servicios WHERE id = ?");
            $stmt->bind_param("i", $servicio_id);
            $stmt->execute();
            $servicio = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$servicio) {
                return ['success' => false, 'message' => 'Servicio no encontrado'];
            }

            $estado_actual = $servicio['estado'];
            $user_id = $usuario_id ?? $servicio['responsable_id'] ?? 1; // Fallback al responsable o admin

            error_log("WORKFLOW DEBUG: Estado actual del servicio #$servicio_id: $estado_actual. Trigger buscado: $trigger_code");

            // 2. Buscar si existe una transición con este disparador desde el estado actual
            $stmt = $conn->prepare("
                SELECT estado_destino_id, nombre 
                FROM transiciones_estado 
                WHERE estado_origen_id = ? 
                  AND trigger_code = ? 
                  AND modulo = 'servicio'
                LIMIT 1
            ");
            $stmt->bind_param("is", $estado_actual, $trigger_code);
            $stmt->execute();
            $transicion = $stmt->get_result()->fetch_assoc();
            $stmt->close();

            if (!$transicion) {
                error_log("WORKFLOW DEBUG: No se encontró transición automática para trigger '$trigger_code' desde el estado '$estado_actual'");
                // No hay transición automática configurada para este evento, no es un error, solo no se hace nada.
                return ['success' => true, 'message' => 'No hay transición automática configurada'];
            }

            $nuevo_estado_id = $transicion['estado_destino_id'];
            error_log("WORKFLOW DEBUG: ¡Transición encontrada! Aplicando cambio de estado: $estado_actual -> $nuevo_estado_id (Trigger: $trigger_code)");

            // 3. VALIDACIÓN: Verificar campos obligatorios del estado ACTUAL antes de permitir la transición automática
            require_once __DIR__ . '/../servicio/helpers/validacion_helper.php';
            try {
                // Al ser automático, arrojamos un error que detenga el flujo si faltan campos
                checkRequiredFields($conn, $servicio_id, $estado_actual, "No se puede ejecutar la transición automática '$trigger_code'.");
            } catch (Exception $e_val) {
                error_log("WORKFLOW ERROR: Validación fallida para trigger $trigger_code: " . $e_val->getMessage());
                return ['success' => false, 'message' => $e_val->getMessage()];
            }

            // 4. Ejecutar el cambio de estado
            require_once __DIR__ . '/../servicio/helpers/estado_helper.php';
            $es_final = esEstadoFinal($conn, $nuevo_estado_id) ? 1 : 0;

            $stmt = $conn->prepare("
                UPDATE servicios 
                SET estado = ?, 
                    es_finalizado = ?, 
                    fecha_actualizacion = NOW(),
                    usuario_ultima_actualizacion = ?
                WHERE id = ?
            ");
            $stmt->bind_param("iiii", $nuevo_estado_id, $es_final, $user_id, $servicio_id);

            if ($stmt->execute()) {
                // ✅ LOG DE TRAZABILIDAD: Registrar cambio de estado automático
                require_once __DIR__ . '/../servicio/helpers/trazabilidad_helper.php';
                TrazabilidadHelper::registrarTransicionEstado($conn, $servicio_id, $nuevo_estado_id, $user_id);

                // ✅ HOOK CONTABLE: Si el nuevo estado es LEGALIZADO, realizar Snapshot
                // Primero obtener el estado base del nuevo estado
                $stmtEB = $conn->prepare("SELECT estado_base_codigo FROM estados_proceso WHERE id = ?");
                $stmtEB->bind_param("i", $nuevo_estado_id);
                $stmtEB->execute();
                $resEB = $stmtEB->get_result()->fetch_assoc();
                $stmtEB->close();

                if ($resEB && $resEB['estado_base_codigo'] === 'LEGALIZADO') {
                    require_once __DIR__ . '/../core/AccountingEngine.php';
                    $snapshotSuccess = AccountingEngine::snapshotService($conn, $servicio_id);
                    if (!$snapshotSuccess) {
                        throw new Exception("ERROR CONTABLE: No se pudo generar el snapshot durante la transición automática.");
                    }
                }

                $conn->commit();

                return [
                    'success' => true,
                    'message' => "Transición automática ejecutada: " . $transicion['nombre'],
                    'new_state' => $nuevo_estado_id
                ];
            } else {
                return ['success' => false, 'message' => 'Error al actualizar estado: ' . $conn->error];
            }

        } catch (Exception $e) {
            if (isset($conn))
                $conn->rollback();
            return ['success' => false, 'message' => 'Excepción en Workflow: ' . $e->getMessage()];
        }
    }
}
