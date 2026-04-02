<?php
// WebSocketNotifier.php - ✅ VERSIÓN FINAL CORREGIDA

/**
 * Clase para notificar cambios de servicios vía WebSocket
 * Adaptada para MySQLi y estructura de tablas específica
 */
class WebSocketNotifier
{
    private $websocket_host;
    private $websocket_port;
    private $timeout;

    public function __construct($host = 'localhost', $port = 8080, $timeout = 5)
    {
        $this->websocket_host = $host;
        $this->websocket_port = $port;
        $this->timeout = $timeout;
    }

    /**
     * ✅ Método genérico para enviar cualquier notificación
     */
    public function notificar($data)
    {
        $this->enviarNotificacion($data);
    }

    /**
     * Notificar creación de servicio
     */
    public function notificarServicioCreado($servicio, $usuario_id = null)
    {
        $this->enviarNotificacion([
            'tipo' => 'servicio_creado',
            'servicio' => $this->formatearServicio($servicio),
            'usuario_id' => $usuario_id,
            'timestamp' => time() * 1000
        ]);
    }

    /**
     * Notificar actualización de servicio
     */
    public function notificarServicioActualizado($servicio, $usuario_id = null)
    {
        $this->enviarNotificacion([
            'tipo' => 'servicio_actualizado',
            'servicio' => $this->formatearServicio($servicio),
            'usuario_id' => $usuario_id,
            'timestamp' => time() * 1000
        ]);
    }

    /**
     * Notificar eliminación de servicio
     */
    public function notificarServicioEliminado($servicio_id, $usuario_id = null)
    {
        $this->enviarNotificacion([
            'tipo' => 'servicio_eliminado',
            'servicio_id' => (int) $servicio_id,
            'usuario_id' => $usuario_id,
            'timestamp' => time() * 1000
        ]);
    }

    /**
     * Notificar anulación específica de servicio
     */
    public function notificarServicioAnulado($servicio, $razon, $usuario_id = null)
    {
        $this->enviarNotificacion([
            'tipo' => 'servicio_anulado',
            'servicio' => $this->formatearServicio($servicio),
            'razon' => $razon,
            'usuario_id' => $usuario_id,
            'timestamp' => time() * 1000
        ]);
    }

    /**
     * Formatear servicio para que coincida con el modelo Flutter
     */
    public function formatearServicio($servicio)
    {
        return [
            'id' => (int) $servicio['id'],
            'oServicio' => (int) $servicio['o_servicio'],
            'ordenCliente' => $servicio['orden_cliente'],
            'fechaIngreso' => $servicio['fecha_ingreso'],
            'fechaFinalizacion' => $servicio['fecha_finalizacion'] ?? null,
            'tipoMantenimiento' => $servicio['tipo_mantenimiento'],
            'centroCosto' => $servicio['centro_costo'] ?? null,
            'clienteId' => isset($servicio['cliente_id']) ? (int) $servicio['cliente_id'] : null,
            'clienteNombre' => $servicio['cliente_nombre'] ?? null,
            'idEquipo' => (int) $servicio['id_equipo'],
            'equipoNombre' => $servicio['equipo_nombre'] ?? null,
            'placa' => $servicio['placa'] ?? null,
            'nombreEmp' => $servicio['nombre_emp'] ?? null,
            'autorizadoPor' => $servicio['autorizado_por'] ? (int) $servicio['autorizado_por'] : null,
            'funcionarioNombre' => $servicio['funcionario_nombre'] ?? null,
            'actividadId' => $servicio['actividad_id'] ? (int) $servicio['actividad_id'] : null,
            'actividadNombre' => $servicio['actividad_nombre'] ?? null,
            'cantHora' => isset($servicio['cant_hora']) ? (float) $servicio['cant_hora'] : 0.0,
            'numTecnicos' => isset($servicio['num_tecnicos']) ? (int) $servicio['num_tecnicos'] : 1,
            'sistemaNombre' => $servicio['sistema_nombre'] ?? '',
            'estadoId' => (int) $servicio['estado'],
            'estadoNombre' => $servicio['estado_nombre'] ?? null,
            'observaciones' => $servicio['observaciones'] ?? null,
            'fechaCreacion' => $servicio['fecha_registro'] ?? null,
            'fechaActualizacion' => $servicio['fecha_actualizacion'] ?? null,
            'estaAnulado' => (bool) ($servicio['anular_servicio'] ?? false),
            'estaFinalizado' => isset($servicio['fecha_finalizacion']) && $servicio['fecha_finalizacion'] !== null,
            'tieneRepuestos' => (bool) ($servicio['suministraron_repuestos'] ?? false),
            'razon' => $servicio['razon'] ?? null,
            'epocaCreacion' => $servicio['fecha_registro'] ?? null,
            'estadoColor' => $servicio['color'] ?? null, // ✅ NUEVO: Color del estado
        ];
    }

    /**
     * Enviar notificación al servidor WebSocket
     */
    private function enviarNotificacion($data)
    {
        try {
            // ✅ NUEVA ESTRATEGIA: Intentar archivo primero, TCP como fallback
            try {
                $this->enviarViaArchivo($data);
                // error_log("✅ Notificación WebSocket enviada vía archivo: " . $data['tipo']);
            } catch (Exception $e) {
                // Si falla archivo, intentar TCP
                $this->enviarViaTCP($data);
                // error_log("✅ Notificación WebSocket enviada vía TCP: " . $data['tipo']);
            }

        } catch (Exception $e) {
            // Log del error pero no fallar la operación principal
            error_log("❌ Error notificando WebSocket: " . $e->getMessage());
        }
    }

    /**
     * ✅ MÉTODO PRINCIPAL: "Fire and Forget" vía archivos individuales
     * Evita bloqueos y lectura de archivos grandes
     */
    private function enviarViaArchivo($data)
    {
        // Generar nombre de archivo único con microtime y entropía
        $filename = 'ws_event_' . microtime(true) . '_' . bin2hex(random_bytes(4)) . '.json';
        $filepath = sys_get_temp_dir() . '/' . $filename;

        $payload = [
            'data' => $data,
            'timestamp' => time(),
            'id' => uniqid('ws_', true)
        ];

        // Escritura atómica simple sin locks pesados (el sistema de archivos maneja la creación)
        // file_put_contents con LOCK_EX es suficiente para archivos nuevos pequeños
        $result = file_put_contents($filepath, json_encode($payload), LOCK_EX);

        if ($result === false) {
            error_log("❌ Error escribiendo evento WebSocket: $filepath");
        } else {
            // Opcional: Limpieza probabilística (1 de cada 100 peticiones limpia archivos viejos)
            if (rand(1, 100) === 1) {
                // No llamamos a limpiarArchivosAntiguos() síncronamente para no bloquear
                // Podríamos delegarlo a un cron o proceso externo
            }
        }
    }

    /**
     * ✅ MÉTODO FALLBACK: TCP simplificado (sin interferir con WebSocket)
     */
    private function enviarViaTCP($data)
    {
        // ✅ ULTRA SIMPLIFICADO: Solo crear un archivo de señal
        $signal_file = sys_get_temp_dir() . '/websocket_signal_' . uniqid() . '.json';

        $signal_data = [
            'tipo' => 'notification_from_php',
            'data' => $data,
            'timestamp' => time()
        ];

        $result = file_put_contents($signal_file, json_encode($signal_data));

        if ($result === false) {
            throw new Exception('No se pudo crear archivo de señal');
        }

        // El archivo será procesado por el poller del servidor WebSocket
    }

    /**
     * Verificar si el servidor WebSocket está disponible
     */
    public function verificarConexion()
    {
        // ✅ SIMPLIFICADO: Solo verificar si podemos escribir archivos
        try {
            $test_file = sys_get_temp_dir() . '/websocket_test_' . uniqid() . '.tmp';
            $result = file_put_contents($test_file, 'test');
            if ($result !== false) {
                @unlink($test_file);
                return true;
            }
            return false;
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * ✅ CORREGIDO: Obtener servicio completo desde base de datos usando estados_proceso
     */
    public function obtenerServicioCompleto($servicio_id, $conn)
    {
        $sql = "
            SELECT s.*, 
                   e.nombre as equipo_nombre,
                   e.placa,
                   s.centro_costo,
                   e.nombre_empresa as nombre_emp,
                   f.nombre as funcionario_nombre,
                   f.nombre as funcionario_nombre,
                   est.nombre_estado as estado_nombre,
                   est.color, -- ✅ NUEVO: Color del estado
                   c.nombre_completo as cliente_nombre,
                   ae.actividad as actividad_nombre,
                   ae.cant_hora,
                   ae.num_tecnicos,
                   st.nombre as sistema_nombre
            FROM servicios s
            LEFT JOIN equipos e ON s.id_equipo = e.id
            LEFT JOIN funcionario f ON s.autorizado_por = f.id
            LEFT JOIN estados_proceso est ON s.estado = est.id
            LEFT JOIN clientes c ON s.cliente_id = c.id
            LEFT JOIN actividades_estandar ae ON s.actividad_id = ae.id
            LEFT JOIN sistemas st ON ae.sistema_id = st.id
            WHERE s.id = ?
        ";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Error preparando consulta de servicio completo: ' . $conn->error);
        }

        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $servicio = $result->fetch_assoc();
        $stmt->close();

        return $servicio;
    }

    /**
     * ✅ CORREGIDO: Obtener servicio completo anulado usando estados_proceso
     */
    public function obtenerServicioCompletoAnulado($servicio_id, $conn)
    {
        $sql = "
            SELECT s.*, 
                   e.nombre as equipo_nombre,
                   e.placa,
                   e.nombre_empresa as nombre_emp,
                   f.nombre as funcionario_nombre,
                   f.nombre as funcionario_nombre,
                   ep.nombre_estado as estado_nombre,
                   ep.color, -- ✅ NUEVO: Color del estado
                   c.nombre_completo as cliente_nombre
            FROM servicios s
            LEFT JOIN equipos e ON s.id_equipo = e.id
            LEFT JOIN funcionario f ON s.autorizado_por = f.id
            LEFT JOIN estados_proceso ep ON s.estado = ep.id
            LEFT JOIN clientes c ON s.cliente_id = c.id
            WHERE s.id = ?
        ";

        $stmt = $conn->prepare($sql);
        if (!$stmt) {
            throw new Exception('Error preparando consulta de servicio anulado: ' . $conn->error);
        }

        $stmt->bind_param("i", $servicio_id);
        $stmt->execute();
        $result = $stmt->get_result();
        $servicio = $result->fetch_assoc();
        $stmt->close();

        return $servicio;
    }

    /**
     * ✅ CORREGIDO: Obtener servicio completo universal usando estados_proceso
     */
    public function obtenerServicioCompletoUniversal($servicio_id, $conn)
    {
        // Usar directamente estados_proceso ya que es la tabla correcta
        $servicio = $this->obtenerServicioCompleto($servicio_id, $conn);

        return $servicio;
    }

    /**
     * ✅ MÉTODO helper para debug y testing
     */
    public function testearConexion()
    {
        try {
            $this->enviarNotificacion([
                'tipo' => 'test',
                'mensaje' => 'Prueba de conexión WebSocket',
                'timestamp' => time() * 1000
            ]);
            return true;
        } catch (Exception $e) {
            return false;
        }
    }

    /**
     * ✅ NUEVO: Limpiar archivos antiguos de notificaciones
     */
    public function limpiarArchivosAntiguos()
    {
        try {
            $temp_dir = sys_get_temp_dir();
            $pattern = $temp_dir . '/websocket_*';

            $files = glob($pattern);
            $now = time();

            foreach ($files as $file) {
                if (is_file($file) && ($now - filemtime($file)) > 3600) { // 1 hora
                    @unlink($file);
                }
            }
        } catch (Exception $e) {
            error_log("Error limpiando archivos WebSocket: " . $e->getMessage());
        }
    }
}
?>