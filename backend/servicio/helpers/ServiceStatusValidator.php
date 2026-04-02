<?php
// backend/servicio/helpers/ServiceStatusValidator.php
// ============================================================
// PRE-FLIGHT VALIDATOR: Validación de integridad antes de
// permitir transiciones a estados finales del servicio.
//
// Regla de negocio: Un servicio SOLO puede alcanzar un estado
// final (LEGALIZADO, FINALIZADO, CERRADO, ENTREGADO) si:
//   1. Todas sus operaciones tienen fecha_fin registrada (no hay abiertas).
//   2. El servicio tiene fecha_finalizacion NOT NULL.
//   3. Existe al menos una firma válida asociada al servicio.
// ============================================================

class ServiceStatusValidator
{
    /**
     * Códigos de estado base que se consideran "finales".
     * Deben coincidir con los valores de estados_proceso.estado_base_codigo
     */
    private static array $FINAL_STATE_CODES = [
        'LEGALIZADO',
        'FINALIZADO',
        'CERRADO',
        'ENTREGADO',
    ];

    // ============================================================
    // MÉTODO PRINCIPAL: Orquestador del Pre-Flight Check
    // ============================================================

    /**
     * Ejecuta los 3 checks de integridad si el estado destino es final.
     * Además, si el estado destino es LEGALIZADO específicamente, ejecuta
     * el check de auditoría financiera obligatoria (SoD).
     *
     * @param mysqli $conn        Conexión a BD (con transacción activa)
     * @param int    $servicio_id ID del servicio a validar
     * @param int    $estado_id   ID del estado destino
     *
     * @throws Exception Con mensaje descriptivo del check que falló
     */
    public static function validatePreFlight(mysqli $conn, int $servicio_id, int $estado_id): void
    {
        // Solo ejecutar si el estado destino es final
        if (!self::esEstadoFinalDestino($conn, $estado_id)) {
            return; // No es estado final, no se requiere validación exhaustiva
        }

        // === PRE-FLIGHT CHECKS (en orden de severidad) ===
        self::checkNoOpenOperations($conn, $servicio_id);
        self::checkFechaFinalizacion($conn, $servicio_id);
        self::checkFirmaValida($conn, $servicio_id);

        // === CHECK SoD: Auditoría financiera obligatoria (solo para LEGALIZADO) ===
        if (self::esEstadoLegalizado($conn, $estado_id)) {
            self::checkAuditoriaObligatoria($conn, $servicio_id);
        }
    }

    // ============================================================
    // MÉTODO PÚBLICO: Verificar si el servicio está apto para auditoria
    // Retorna true/false SIN lanzar excepciones.
    // Usado por check_auditoria.php para informar al frontend.
    // ============================================================

    /**
     * Verifica si el servicio cumple los 3 pre-requisitos de integridad
     * para poder ser auditado (y posteriormente legalizado).
     *
     * @param mysqli $conn
     * @param int    $servicio_id
     * @return bool  true si el servicio está listo para tramitar auditoría
     */
    public static function esAptoParaAuditoria(mysqli $conn, int $servicio_id): bool
    {
        // Check 0: ¿El estado actual tiene transición a LEGALIZADO?
        $sqlEstado = "
            SELECT s.estado, ep.nombre_estado, b.codigo AS estado_base
            FROM servicios s
            JOIN estados_proceso ep ON s.estado = ep.id
            JOIN estados_base b ON ep.estado_base_codigo = b.codigo
            WHERE s.id = ?
        ";
        $stmt0 = $conn->prepare($sqlEstado);
        $stmt0->bind_param("i", $servicio_id);
        $stmt0->execute();
        $srvData = $stmt0->get_result()->fetch_assoc();
        $stmt0->close();

        if (!$srvData) return false;

        // Si ya está en un estado final (LEGALIZADO, etc.), ya no es "apto para auditar" (ya pasó o está ahí)
        if (in_array($srvData['estado_base'], self::$FINAL_STATE_CODES)) {
            return false;
        }

        // Verificar si existe una transición desde el estado actual hacia un estado LEGALIZADO
        $sqlTrans = "
            SELECT COUNT(*) AS total
            FROM transiciones_estado t
            JOIN estados_proceso ep ON t.estado_destino_id = ep.id
            WHERE t.estado_origen_id = ?
              AND (ep.estado_base_codigo = 'LEGALIZADO' OR ep.nombre_estado LIKE '%LEGALIZADO%')
        ";
        $stmtT = $conn->prepare($sqlTrans);
        $stmtT->bind_param("i", $srvData['estado']);
        $stmtT->execute();
        $rowT = $stmtT->get_result()->fetch_assoc();
        $stmtT->close();

        if ((int) $rowT['total'] === 0) {
            return false; // No hay transición directa a Legalizado
        }

        // Check 1: Ninguna operación abierta
        $sqlOps = "SELECT COUNT(*) AS total FROM operaciones
                   WHERE servicio_id = ? AND fecha_fin IS NULL";
        $stmt = $conn->prepare($sqlOps);
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();
        if ((int) $row['total'] > 0)
            return false;

        // Check 2: Fecha de finalización registrada
        $stmt2 = $conn->prepare("SELECT fecha_finalizacion FROM servicios WHERE id = ? LIMIT 1");
        $stmt2->bind_param("i", $servicio_id);
        $stmt2->execute();
        $srv = $stmt2->get_result()->fetch_assoc();
        $stmt2->close();
        if (!$srv || empty($srv['fecha_finalizacion']))
            return false;

        // Check 3: Al menos una firma válida
        $sqlFirma = "SELECT COUNT(*) AS total FROM firmas
                     WHERE id_servicio = ?
                       AND ((firma_staff_base64 IS NOT NULL AND firma_staff_base64 != '')
                            OR (firma_funcionario_base64 IS NOT NULL AND firma_funcionario_base64 != ''))";
        $stmt3 = $conn->prepare($sqlFirma);
        $stmt3->bind_param("i", $servicio_id);
        $stmt3->execute();
        $rowFirma = $stmt3->get_result()->fetch_assoc();
        $stmt3->close();
        if ((int) $rowFirma['total'] === 0)
            return false;

        return true;
    }

    // ============================================================
    // CHECK 1: Cero Operaciones Abiertas
    // ============================================================

    /**
     * Verifica que todas las operaciones del servicio tengan fecha_fin registrada.
     * Una operación sin fecha_fin se considera "abierta/pendiente".
     *
     * @throws Exception Si existe al menos una operación sin fecha_fin
     */
    private static function checkNoOpenOperations(mysqli $conn, int $servicio_id): void
    {
        $sql = "
            SELECT COUNT(*) AS total_abiertas,
                   GROUP_CONCAT(
                       COALESCE(descripcion, CONCAT('Operación #', id))
                       ORDER BY id
                       SEPARATOR ' | '
                   ) AS nombres_abiertas
            FROM operaciones
            WHERE servicio_id = ?
              AND fecha_fin IS NULL
        ";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ((int) $result['total_abiertas'] > 0) {
            $n = $result['total_abiertas'];
            $lista = $result['nombres_abiertas'] ?? 'sin nombre';
            throw new Exception(
                "El servicio no puede finalizar porque aún tiene {$n} " .
                ($n === 1 ? "actividad abierta" : "actividades abiertas") .
                ". Por cerrar: {$lista}."
            );
        }
    }

    // ============================================================
    // CHECK 2: Fecha de Finalización Registrada
    // ============================================================

    /**
     * Verifica que el campo fecha_finalizacion del servicio sea NOT NULL.
     *
     * @throws Exception Si fecha_finalizacion es NULL o el servicio no existe
     */
    private static function checkFechaFinalizacion(mysqli $conn, int $servicio_id): void
    {
        $stmt = $conn->prepare("SELECT fecha_finalizacion FROM servicios WHERE id = ?");
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$result) {
            throw new Exception("El servicio #{$servicio_id} no fue encontrado al validar fecha de finalización.");
        }

        if (empty($result['fecha_finalizacion'])) {
            throw new Exception(
                "El servicio no puede finalizar porque no tiene fecha de finalización registrada. " .
                "Por favor, registre la fecha en la que se completó el trabajo."
            );
        }
    }

    // ============================================================
    // CHECK 3: Firma Válida Capturada
    // ============================================================

    /**
     * Verifica que exista al menos una firma registrada para el servicio,
     * con al menos uno de los campos de firma en base64 no nulo.
     *
     * @throws Exception Si no existe ninguna firma válida para el servicio
     */
    private static function checkFirmaValida(mysqli $conn, int $servicio_id): void
    {
        $sql = "
            SELECT COUNT(*) AS total_firmas
            FROM firmas
            WHERE id_servicio = ?
              AND (
                  (firma_staff_base64 IS NOT NULL AND firma_staff_base64 != '')
                  OR
                  (firma_funcionario_base64 IS NOT NULL AND firma_funcionario_base64 != '')
              )
        ";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if ((int) $result['total_firmas'] === 0) {
            throw new Exception(
                "El servicio no puede finalizar porque no tiene una firma válida registrada. " .
                "Se requiere la firma del cliente o del personal técnico para proceder."
            );
        }
    }

    // ============================================================
    // HELPER PRIVADO: Detectar estado final
    // ============================================================

    /**
     * Determina si el estado destino es un estado final consultando
     * el campo estado_base_codigo en estados_proceso.
     *
     * @return bool true si el estado es final
     */
    private static function esEstadoFinalDestino(mysqli $conn, int $estado_id): bool
    {
        $stmt = $conn->prepare(
            "SELECT estado_base_codigo, nombre_estado FROM estados_proceso WHERE id = ? LIMIT 1"
        );
        $stmt->bind_param("i", $estado_id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$row) {
            return false;
        }

        $base_code = strtoupper(trim($row['estado_base_codigo'] ?? ''));
        $nombre = strtoupper(trim($row['nombre_estado'] ?? ''));

        // Verificar por código base primero (más confiable)
        if (in_array($base_code, self::$FINAL_STATE_CODES)) {
            return true;
        }

        // Fallback: verificar por palabras clave en el nombre del estado
        foreach (self::$FINAL_STATE_CODES as $palabra) {
            if (str_contains($nombre, $palabra)) {
                return true;
            }
        }

        return false;
    }

    // ============================================================
    // HELPER PRIVADO: Detectar LEGALIZADO específicamente
    // ============================================================

    /**
     * Determina si el estado destino es específicamente LEGALIZADO.
     * Más estricto que esEstadoFinalDestino(): solo activa el check SoD.
     *
     * @return bool true si el estado_base_codigo es 'LEGALIZADO' o el nombre contiene 'LEGALIZADO'
     */
    private static function esEstadoLegalizado(mysqli $conn, int $estado_id): bool
    {
        $stmt = $conn->prepare(
            "SELECT estado_base_codigo, nombre_estado FROM estados_proceso WHERE id = ? LIMIT 1"
        );
        $stmt->bind_param("i", $estado_id);
        $stmt->execute();
        $row = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$row) {
            return false;
        }

        $base_code = strtoupper(trim($row['estado_base_codigo'] ?? ''));
        $nombre = strtoupper(trim($row['nombre_estado'] ?? ''));

        return $base_code === 'LEGALIZADO' || str_contains($nombre, 'LEGALIZADO');
    }

    // ============================================================
    // CHECK 4 (SoD): Auditoría Financiera Obligatoria
    // ============================================================

    /**
     * Verifica que el servicio haya sido auditado por un auditor financiero
     * ANTES de ser legalizado.
     *
     * Lógica flexible:
     *   - Si NO hay auditores activos en el sistema → el check pasa silenciosamente.
     *   - Si HAY auditores → el servicio DEBE tener un registro en fac_auditorias_servicio.
     *
     * @throws Exception Si hay auditores pero el servicio no ha sido auditado.
     */
    private static function checkAuditoriaObligatoria(mysqli $conn, int $servicio_id): void
    {
        // 1. ¿Existen auditores activos en el sistema? Obtener sus nombres para el mensaje.
        $sqlAuditores = "SELECT NOMBRE_USER AS nombre FROM usuarios WHERE es_auditor = 1 AND ESTADO_USER = 'activo'";
        $resultAuditores = $conn->query($sqlAuditores);

        $nombresAuditores = [];
        while ($row = $resultAuditores->fetch_assoc()) {
            $nombresAuditores[] = $row['nombre'];
        }

        $totalAuditores = count($nombresAuditores);

        // Flexible: si no hay auditores, no hay restricción
        if ($totalAuditores === 0) {
            return;
        }

        // 2. Obtener el ciclo actual de este servicio
        $stmtCiclo = $conn->prepare("SELECT ciclo_actual FROM fac_audit_ciclos WHERE servicio_id = ? LIMIT 1");
        $stmtCiclo->bind_param("i", $servicio_id);
        $stmtCiclo->execute();
        $cicloRow = $stmtCiclo->get_result()->fetch_assoc();
        $stmtCiclo->close();
        $ciclo_actual = $cicloRow ? (int) $cicloRow['ciclo_actual'] : 1;

        // 3. ¿El servicio fue auditado en el ciclo actual?
        $stmtAuditoria = $conn->prepare(
            "SELECT id FROM fac_auditorias_servicio WHERE servicio_id = ? AND ciclo = ? LIMIT 1"
        );
        $stmtAuditoria->bind_param("ii", $servicio_id, $ciclo_actual);
        $stmtAuditoria->execute();
        $auditoria = $stmtAuditoria->get_result()->fetch_assoc();
        $stmtAuditoria->close();

        if (!$auditoria) {
            $listaNombres = implode(", ", $nombresAuditores);
            throw new Exception(
                "Esta operación requiere auditoría para cambiar de estado. " .
                "Por favor, solicite a un auditor autorizado (ej: {$listaNombres}) " .
                "que realice la validación."
            );
        }
    }
}
