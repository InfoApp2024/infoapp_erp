<?php
/**
 * AccountingEngine.php
 * Clase núcleo para la integración contable de InfoApp
 * Autor: Senior Developer / Architect
 */

class AccountingEngine
{

    /**
     * Realiza un Snapshot (fotografía) de los valores de la OT al legalizar.
     * Fase 1: Inmutabilidad financiera.
     * 
     * @param mysqli $conn Conexión a BD
     * @param int $servicio_id ID del servicio
     * @return booléan True si fue exitoso
     */
    public static function snapshotService($conn, $servicio_id)
    {
        try {
            // 0. Obtener cliente_id del servicio
            $sqlS = "SELECT cliente_id FROM servicios WHERE id = ?";
            $stmtS = $conn->prepare($sqlS);
            $stmtS->bind_param("i", $servicio_id);
            $stmtS->execute();
            $resS = $stmtS->get_result()->fetch_assoc();
            $cliente_id = $resS['cliente_id'] ?? null;
            $stmtS->close();

            if (!$cliente_id) {
                throw new Exception("El servicio no tiene un cliente asociado.");
            }

            // 1. Calcular total de repuestos
            $sqlRepuestos = "SELECT SUM(cantidad * costo_unitario) as total FROM servicio_repuestos WHERE servicio_id = ?";
            $stmtR = $conn->prepare($sqlRepuestos);
            $stmtR->bind_param("i", $servicio_id);
            $stmtR->execute();
            $resR = $stmtR->get_result()->fetch_assoc();
            $totalRepuestos = (float) ($resR['total'] ?? 0);
            $stmtR->close();

            // 2. Calcular total de Mano de Obra (M.O.)
            // Basado en el personal asignado (servicio_staff) y el tiempo de sus operaciones

            // Primero obtenemos la Operación Maestra para usarla como fallback
            $sqlMaster = "SELECT id, fecha_inicio, fecha_fin FROM operaciones WHERE servicio_id = ? AND is_master = 1 LIMIT 1";
            $stMaster = $conn->prepare($sqlMaster);
            $stMaster->bind_param("i", $servicio_id);
            $stMaster->execute();
            $masterOp = $stMaster->get_result()->fetch_assoc();
            $stMaster->close();

            // Consultamos todo el staff asignado y vinculamos con sus operaciones
            $sqlStaff = "SELECT ss.staff_id, ss.operacion_id, 
                               u.ID_ESPECIALIDAD,
                               o.fecha_inicio, o.fecha_fin
                        FROM servicio_staff ss
                        JOIN usuarios u ON ss.staff_id = u.id
                        LEFT JOIN operaciones o ON ss.operacion_id = o.id
                        WHERE ss.servicio_id = ?";

            $stStaff = $conn->prepare($sqlStaff);
            $stStaff->bind_param("i", $servicio_id);
            $stStaff->execute();
            $resStaff = $stStaff->get_result();

            $totalManoObra = 0;

            // Función auxiliar interna para obtener tarifa
            $getTarifa = function ($especialidad_id, $cliente_id) use ($conn) {
                if (!$especialidad_id)
                    return 0;

                $sqlT = "SELECT cp.valor FROM cliente_perfiles cp WHERE cp.cliente_id = ? AND cp.especialidad_id = ? LIMIT 1";
                $stT = $conn->prepare($sqlT);
                $stT->bind_param("ii", $cliente_id, $especialidad_id);
                $stT->execute();
                $rT = $stT->get_result()->fetch_assoc();
                $stT->close();

                if ($rT)
                    return (float) $rT['valor'];

                $sqlB = "SELECT valor_hr FROM especialidades WHERE id = ? LIMIT 1";
                $stB = $conn->prepare($sqlB);
                $stB->bind_param("i", $especialidad_id);
                $stB->execute();
                $rB = $stB->get_result()->fetch_assoc();
                $stB->close();
                return (float) ($rB['valor_hr'] ?? 0);
            };

            while ($staff = $resStaff->fetch_assoc()) {
                // Si la asignación no tiene operación, o la operación no tiene fechas, usamos las de la Maestra
                $f_inicio = $staff['fecha_inicio'] ?? ($masterOp['fecha_inicio'] ?? null);
                $f_fin = $staff['fecha_fin'] ?? ($masterOp['fecha_fin'] ?? null);

                if ($f_inicio && $f_fin) {
                    $inicio = new DateTime($f_inicio);
                    $fin = new DateTime($f_fin);
                    $intervalo = $inicio->diff($fin);
                    $horasReal = $intervalo->h + ($intervalo->i / 60) + ($intervalo->s / 3600) + ($intervalo->days * 24);

                    $esp_id = $staff['ID_ESPECIALIDAD'];
                    $tarifa = $getTarifa($esp_id, $cliente_id);

                    // DIAGNOSTICO: Loguear valores
                    error_log("AccountingEngine [MO]: Staff ID {$staff['staff_id']} | Horas: $horasReal | Tarifa: $tarifa");

                    $totalManoObra += ($horasReal * $tarifa);
                } else {
                    error_log("AccountingEngine [MO]: Staff ID {$staff['staff_id']} omitido por falta de fechas (Op: " . ($staff['operacion_id'] ?? 'NULL') . ")");
                }
            }
            $stStaff->close();

            error_log("AccountingEngine [MO]: Servicio $servicio_id | Total MO Final: $totalManoObra");

            $valorTotal = $totalRepuestos + $totalManoObra;

            // 3. Crear o actualizar el registro en fac_control_servicios y actualizar servicios.estado_financiero_id
            $sqlInsert = "INSERT INTO fac_control_servicios (servicio_id, valor_snapshot, total_repuestos, total_mano_obra, total_facturado, estado_comercial_cache) 
                          VALUES (?, ?, ?, ?, 0, 'PENDIENTE_CAUSACION')
                          ON DUPLICATE KEY UPDATE 
                            valor_snapshot = VALUES(valor_snapshot),
                            total_repuestos = VALUES(total_repuestos),
                            total_mano_obra = VALUES(total_mano_obra)";

            $stmtI = $conn->prepare($sqlInsert);
            $stmtI->bind_param("iddd", $servicio_id, $valorTotal, $totalRepuestos, $totalManoObra);
            $success = $stmtI->execute();
            $stmtI->close();

            // Automatización: Cambiar el estado financiero a FIN_PENDIENTE si no tiene estado.
            $sqlFin = "UPDATE servicios s
                       JOIN estados_proceso ep ON ep.estado_base_codigo = 'FIN_PENDIENTE' AND ep.modulo = 'FINANCIERO'
                       SET s.estado_financiero_id = ep.id, s.estado_fin_fecha_inicio = NOW()
                       WHERE s.id = ? AND s.estado_financiero_id IS NULL";
            $stFin = $conn->prepare($sqlFin);
            $stFin->bind_param("i", $servicio_id);
            $stFin->execute();
            $stFin->close();

            return $success;
        } catch (Exception $e) {
            error_log("AccountingEngine Error: " . $e->getMessage());
            // Lanzar excepción para que el orquestador (cambiar_estado_servicio.php) pueda mostrar el error real.
            throw new Exception("Error en snapshot contable de OT $servicio_id: " . $e->getMessage());
        }
    }

    /**
     * Valida si un periodo contable está abierto.
     * Si no existe el periodo o está cerrado, lanza una excepción.
     * 
     * @param mysqli $conn
     * @param string $fecha YYYY-MM-DD
     * @throws Exception
     */
    public static function validatePeriod($conn, $fecha)
    {
        $anio = (int) date('Y', strtotime($fecha));
        $mes = (int) date('n', strtotime($fecha));

        $sql = "SELECT estado FROM fin_periodos WHERE anio = ? AND mes = ? LIMIT 1";
        $stmt = $conn->prepare($sql);
        $stmt->bind_param("ii", $anio, $mes);
        $stmt->execute();
        $res = $stmt->get_result()->fetch_assoc();
        $stmt->close();

        if (!$res) {
            throw new Exception("ERROR CONTABLE: El periodo contable ($anio-$mes) no ha sido creado.");
        }

        if ($res['estado'] !== 'ABIERTO') {
            throw new Exception("ERROR CONTABLE: El periodo contable ($anio-$mes) está CERRADO. No se permiten movimientos.");
        }

        return true;
    }

    /**
     * Genera una propuesta de asiento contable basada en la matriz de causación.
     * Desacopla la lógica de negocio de los códigos de cuenta.
     * 
     * @param mysqli $conn
     * @param string $evento Ej: 'GENERAR_FACTURA'
     * @param array $montos ['TOTAL' => X, 'SUBTOTAL' => Y, 'IMPUESTO' => Z]
     * @param string $referencia
     * @param array $extraDetalles Detalles adicionales inyectados dinámicamente (ej: retenciones discriminadas)
     * @return array Estructura del asiento para persistir
     */
    public static function generateEntry($conn, $evento, $montos, $referencia, $extraDetalles = [])
    {
        // 1. Obtener reglas de causación para el evento
        $sql = "SELECT c.tipo_movimiento, c.base_calculo, c.porcentaje, p.codigo_cuenta, p.nombre as cuenta_nombre, p.id as cuenta_id
                FROM fin_config_causacion c
                JOIN fin_puc p ON c.puc_cuenta_id = p.id
                WHERE c.evento_codigo = ? AND c.activo = 1";

        $stmt = $conn->prepare($sql);
        $stmt->bind_param("s", $evento);
        $stmt->execute();
        $rules = $stmt->get_result()->fetch_all(MYSQLI_ASSOC);
        $stmt->close();

        if (empty($rules) && empty($extraDetalles)) {
            throw new Exception("ERROR CONTABLE: No hay reglas de causación configuradas para el evento '$evento' ni detalles extra.");
        }

        // --- DEDUPLICACIÓN DE REGLAS (Auditoría OT 1288/1298) ---
        // Evita que el valor se multiplique si existen reglas duplicadas en la base de datos
        $uniqueRules = [];
        foreach ($rules as $r) {
            $rKey = $r['base_calculo'] . '|' . $r['codigo_cuenta'] . '|' . $r['tipo_movimiento'] . '|' . $r['porcentaje'];
            if (!isset($uniqueRules[$rKey])) {
                $uniqueRules[$rKey] = $r;
            }
        }
        $rules = array_values($uniqueRules);

        $asiento = [
            'referencia' => $referencia,
            'evento' => $evento,
            'detalles' => []
        ];

        // 2. Procesar reglas estándar de la matriz
        foreach ($rules as $rule) {
            $baseKey = strtoupper($rule['base_calculo']);
            $base = isset($montos[$baseKey]) ? (float) $montos[$baseKey] : 0;

            $valorCalculado = round($base * ($rule['porcentaje'] / 100), 2);

            if ($valorCalculado == 0)
                continue;

            $asiento['detalles'][] = [
                'cuenta_id' => $rule['cuenta_id'],
                'codigo' => $rule['codigo_cuenta'],
                'nombre' => $rule['cuenta_nombre'],
                'tipo' => $rule['tipo_movimiento'],
                'valor' => $valorCalculado
            ];
        }

        // Deduplicar entradas generadas por reglas: si la misma cuenta (codigo+tipo)
        // aparece por múltiples reglas de causación, se fusionan sumando el valor.
        $deduped = [];
        foreach ($asiento['detalles'] as $det) {
            $key = $det['codigo'] . '|' . $det['tipo'];
            if (isset($deduped[$key])) {
                $deduped[$key]['valor'] = round($deduped[$key]['valor'] + $det['valor'], 2);
            } else {
                $deduped[$key] = $det;
            }
        }
        $asiento['detalles'] = array_values($deduped);

        // 3. Inyectar detalles extra (Desglose dinámico exigido en OT 1288)
        foreach ($extraDetalles as $extra) {
            if ($extra['valor'] == 0)
                continue;

            // Resolución automática de ID de cuenta si solo viene el código (Ticket #1302 Bug Fix)
            if (!isset($extra['cuenta_id']) && isset($extra['codigo'])) {
                $stPid = $conn->prepare("SELECT id FROM fin_puc WHERE codigo_cuenta = ? LIMIT 1");
                $stPid->bind_param("s", $extra['codigo']);
                $stPid->execute();
                $pidRes = $stPid->get_result()->fetch_assoc();
                if ($pidRes) {
                    $extra['cuenta_id'] = $pidRes['id'];
                }
                $stPid->close();
            }

            // Mapeo base
            $detalle = [
                'cuenta_id' => $extra['cuenta_id'] ?? null,
                'codigo' => $extra['codigo'],
                'nombre' => $extra['nombre'],
                'tipo' => $extra['tipo'],
                'valor' => round($extra['valor'], 2)
            ];

            // Preservar cualquier campo adicional inyectado (ej: inventory_item_id para Phase 3.9)
            foreach ($extra as $key => $val) {
                if (!isset($detalle[$key])) {
                    $detalle[$key] = $val;
                }
            }

            $asiento['detalles'][] = $detalle;
        }

        return $asiento;
    }

    /**
     * Recalcula el estado comercial de una OT basado en las facturas vinculadas.
     * Automatización Req 2.2: NO_FACTURADO -> FACTURACION_PARCIAL -> FACTURADO_TOTAL
     * 
     * @param mysqli $conn
     * @param int $servicio_id
     * @return string Nuevo estado calculado
     */
    public static function recalculateCommercialState($conn, $servicio_id)
    {
        // 1. Obtener el valor_snapshot (techo financiero)
        $sqlS = "SELECT valor_snapshot, estado_comercial_cache FROM fac_control_servicios WHERE servicio_id = ?";
        $stmtS = $conn->prepare($sqlS);
        $stmtS->bind_param("i", $servicio_id);
        $stmtS->execute();
        $snap = $stmtS->get_result()->fetch_assoc();
        $stmtS->close();

        if (!$snap)
            return 'NO_FACTURADO';

        $valorSnapshot = (float) $snap['valor_snapshot'];

        // 2. Sumar todo lo facturado hasta el momento para esta OT (según fac_factura_items)
        // Solo sumamos de facturas que no estén ANULADAS
        $sqlF = "SELECT SUM(fi.monto_repuestos + fi.monto_mano_obra) as total_acumulado
                FROM fac_factura_items fi
                JOIN fac_facturas f ON fi.factura_id = f.id
                WHERE fi.servicio_id = ? AND f.estado != 'ANULADA'";
        $stmtF = $conn->prepare($sqlF);
        $stmtF->bind_param("i", $servicio_id);
        $stmtF->execute();
        $resF = $stmtF->get_result()->fetch_assoc();
        $stmtF->close();

        $totalFacturado = (float) ($resF['total_acumulado'] ?? 0);

        // 3. Determinar nuevo estado
        $nuevoEstado = 'NO_FACTURADO';

        // Si ya fue "CAUSADO" (hito contable), mantenemos ese hito si no hay facturas
        if ($totalFacturado == 0) {
            $nuevoEstado = ($snap['estado_comercial_cache'] === 'CAUSADO') ? 'CAUSADO' : 'NO_FACTURADO';
        } else if ($totalFacturado < ($valorSnapshot - 0.01)) { // Margen de centavo
            $nuevoEstado = 'FACTURACION_PARCIAL';
        } else {
            $nuevoEstado = 'FACTURADO_TOTAL';
        }

        // 4. Persistir el recálculo (Mantenemos cache comercial para retrocompatibilidad)
        $sqlUpd = "UPDATE fac_control_servicios 
                   SET total_facturado = ?, estado_comercial_cache = ? 
                   WHERE servicio_id = ?";
        $stmtU = $conn->prepare($sqlUpd);
        $stmtU->bind_param("dsi", $totalFacturado, $nuevoEstado, $servicio_id);
        $stmtU->execute();
        $stmtU->close();

        // 5. Automatización Híbrida FACTURA: 
        // Si el total_facturado es > 0, forzamos el estado FINANCIERO a FACTURADO 
        // (Asumiendo que se generó la factura).
        if ($totalFacturado > 0) {
            $sqlFin = "UPDATE servicios s 
                       JOIN estados_proceso ep ON ep.estado_base_codigo = 'FIN_FACTURADO' AND ep.modulo = 'FINANCIERO'
                       SET s.estado_financiero_id = ep.id, s.estado_fin_fecha_inicio = NOW()
                       WHERE s.id = ? AND s.estado_financiero_id != ep.id";
            $stFin = $conn->prepare($sqlFin);
            $stFin->bind_param("i", $servicio_id);
            $stFin->execute();
            $stFin->close();
            
            // Log de la transición automática
            $sqlLog = "INSERT INTO estados_servicios_log (servicio_id, estado_anterior_id, estado_nuevo_id, modulo, usuario_id, observacion)
                       SELECT ?, NULL, ep.id, 'FINANCIERO', 1, 'Generación/Recálculo Automático de Factura Comercial'
                       FROM estados_proceso ep WHERE ep.estado_base_codigo = 'FIN_FACTURADO' AND ep.modulo = 'FINANCIERO' LIMIT 1";
            $sl = $conn->prepare($sqlLog);
            $sl->bind_param("i", $servicio_id);
            $sl->execute();
            $sl->close();
        }

        error_log("AccountingEngine [Recalculate]: Servicio $servicio_id | Facturado: $totalFacturado | Snapshot: $valorSnapshot | Nuevo Estado: $nuevoEstado");

        return $nuevoEstado;
    }
}
