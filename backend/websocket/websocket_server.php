<?php
// websocket_server.php - ✅ VERSIÓN FINAL CON TODAS LAS MEJORAS

/**
 * Servidor WebSocket simple para notificaciones de servicios
 * Compatible sin dependencias externas
 */
class ServiciosWebSocketServer
{
    private $clients = [];
    private $socket;
    private $port;
    private $last_cleanup = 0;
    private $last_file_check = 0;

    public function __construct($port = 8080)
    {
        $this->port = $port;
        echo "🚀 Iniciando servidor WebSocket en puerto $port...\n";

        // Crear socket del servidor
        $this->socket = socket_create(AF_INET, SOCK_STREAM, SOL_TCP);
        if (!$this->socket) {
            die("❌ Error creando socket: " . socket_strerror(socket_last_error()) . "\n");
        }

        // Configurar socket
        socket_set_option($this->socket, SOL_SOCKET, SO_REUSEADDR, 1);

        // Bindear y escuchar
        if (!socket_bind($this->socket, '0.0.0.0', $port)) {
            die("❌ Error binding socket: " . socket_strerror(socket_last_error()) . "\n");
        }

        if (!socket_listen($this->socket, 5)) {
            die("❌ Error listening socket: " . socket_strerror(socket_last_error()) . "\n");
        }

        echo "✅ Servidor WebSocket iniciado correctamente\n";
        require '../conexion.php';
        echo "📡 Esperando conexiones en ws://localhost:$port\n";
        echo "🔄 Presiona Ctrl+C para detener\n\n";
    }

    public function run()
    {
        $last_debug = time();

        while (true) {
            // ✅ NUEVO: Debug periódico
            if (time() - $last_debug > 30) {
                echo "📊 Estado: " . count($this->clients) . " clientes conectados\n";
                $last_debug = time();
            }

            // ✅ NUEVO: Verificar archivos de notificaciones
            $this->checkFileNotifications();

            // ✅ NUEVO: Verificar archivos de señales
            $this->checkSignalFiles();

            // Preparar array de sockets para select
            $read_sockets = array_merge([$this->socket], $this->clients);
            $write = [];
            $except = [];

            // Esperar actividad en algún socket
            $activity = socket_select($read_sockets, $write, $except, 1);

            if ($activity === false) {
                echo "❌ Error en socket_select\n";
                break;
            }

            // Nueva conexión
            if (in_array($this->socket, $read_sockets)) {
                $new_socket = socket_accept($this->socket);
                if ($new_socket) {
                    $this->handleNewConnection($new_socket);
                }

                // Remover el socket servidor de la lista
                $key = array_search($this->socket, $read_sockets);
                unset($read_sockets[$key]);
            }

            // Manejar actividad en clientes existentes
            foreach ($read_sockets as $client_socket) {
                $this->handleClientMessage($client_socket);
            }

            // ✅ NUEVO: Limpiar conexiones cerradas y archivos antiguos
            $this->cleanupClosedConnections();
            $this->cleanupOldFiles();
        }
    }

    private function handleNewConnection($socket)
    {
        // Leer request HTTP completo
        $request = '';
        $bytes_read = 0;

        while ($bytes_read < 2048) {
            $chunk = socket_read($socket, 1024);
            if ($chunk === false || $chunk === '') {
                break;
            }
            $request .= $chunk;
            $bytes_read += strlen($chunk);

            // Si tenemos los headers completos, parar
            if (strpos($request, "\r\n\r\n") !== false) {
                break;
            }
        }

        if ($request) {
            try {
                // Crear handshake WebSocket
                $response = $this->createWebSocketHandshake($request);

                // Enviar respuesta
                $bytes_sent = socket_write($socket, $response, strlen($response));

                if ($bytes_sent === false) {
                    echo "❌ Error enviando handshake\n";
                    socket_close($socket);
                    return;
                }

                // Agregar cliente SOLO después de handshake exitoso
                $this->clients[] = $socket;
                $client_id = array_search($socket, $this->clients);

                echo "⚡ Nueva conexión: Cliente #$client_id\n";

                // ✅ Esperar un momento antes de enviar mensaje de bienvenida
                usleep(100000); // 100ms

                // Enviar mensaje de bienvenida
                $this->sendToClient($socket, [
                    'tipo' => 'connected',
                    'mensaje' => 'Conectado al servidor de servicios',
                    'timestamp' => time() * 1000
                ]);

            } catch (Exception $e) {
                echo "❌ Error en handshake: " . $e->getMessage() . "\n";
                socket_close($socket);
            }
        } else {
            echo "❌ Request vacío, cerrando conexión\n";
            socket_close($socket);
        }
    }

    private function handleClientMessage($socket)
    {
        $message = socket_read($socket, 2048);

        if ($message === false || $message === '') {
            // Cliente desconectado
            $this->removeClient($socket);
            return;
        }

        try {
            // Decodificar mensaje WebSocket
            $decoded = $this->decodeWebSocketMessage($message);
            if ($decoded) {
                $data = json_decode($decoded, true);
                if ($data) {
                    $this->processMessage($data, $socket);
                }
            }
        } catch (Exception $e) {
            echo "❌ Error procesando mensaje: " . $e->getMessage() . "\n";
        }
    }

    private function processMessage($data, $sender_socket = null)
    {
        // ✅ NUEVO: Validar estructura del mensaje
        if (!isset($data['tipo'])) {
            echo "⚠️ Mensaje sin tipo ignorado\n";
            return;
        }

        // ✅ NUEVO: Rate limiting básico
        static $last_message_time = [];
        $client_id = array_search($sender_socket, $this->clients);
        $current_time = time();

        if (
            isset($last_message_time[$client_id]) &&
            ($current_time - $last_message_time[$client_id]) < 1
        ) {
            echo "⚠️ Rate limit alcanzado para cliente #$client_id\n";
            return;
        }
        $last_message_time[$client_id] = $current_time;

        $tipo = $data['tipo'];
        echo "📨 Cliente #$client_id → Tipo: $tipo\n";

        switch ($tipo) {
            case 'ping':
                $this->sendToClient($sender_socket, [
                    'tipo' => 'pong',
                    'timestamp' => time() * 1000
                ]);
                break;

            case 'auth':
                $this->sendToClient($sender_socket, [
                    'tipo' => 'auth_success',
                    'timestamp' => time() * 1000
                ]);
                echo "🔐 Cliente #$client_id autenticado\n";
                break;

            case 'notification':
                // Notificación desde PHP API - difundir a todos los clientes
                $notification_data = $data['data'] ?? $data;
                $this->broadcastNotification($notification_data, $sender_socket);
                break;

            case 'notification_from_php':
                // ✅ NUEVO: Manejar notificaciones desde PHP
                $notification_data = $data['data'] ?? $data;
                $this->broadcastToAll($notification_data);
                echo "📡 Notificación desde PHP difundida\n";
                break;

            case 'servicio_creado':
            case 'servicio_actualizado':
            case 'servicio_eliminado':
            case 'servicio_anulado':
                // Difundir directamente
                $this->broadcastNotification($data, $sender_socket);
                break;

            default:
                echo "⚠️ Tipo de mensaje no manejado: $tipo\n";
        }
    }

    /**
     * ✅ NUEVO: Verificar archivos de notificaciones principales
     */
    private function checkFileNotifications()
    {
        // Verificar cada 2 segundos
        if (time() - $this->last_file_check < 2)
            return;
        $this->last_file_check = time();

        $notification_file = sys_get_temp_dir() . '/websocket_notifications.json';

        if (!file_exists($notification_file))
            return;

        $notifications = @json_decode(file_get_contents($notification_file), true);
        if (!$notifications)
            return;

        $updated = false;

        foreach ($notifications as &$notification) {
            if (!$notification['processed']) {
                $this->broadcastToAll($notification['data']);
                $notification['processed'] = true;
                $updated = true;
                echo "📡 Notificación de archivo procesada\n";
            }
        }

        if ($updated) {
            file_put_contents($notification_file, json_encode($notifications, JSON_PRETTY_PRINT));
        }
    }

    /**
     * ✅ NUEVO: Verificar archivos de señales individuales
     */
    private function checkSignalFiles()
    {
        $temp_dir = sys_get_temp_dir();
        $pattern = $temp_dir . '/websocket_signal_*.json';

        $files = glob($pattern);

        foreach ($files as $file) {
            try {
                $signal_data = @json_decode(file_get_contents($file), true);

                if ($signal_data && isset($signal_data['data'])) {
                    $this->broadcastToAll($signal_data['data']);
                    echo "📡 Señal de archivo procesada\n";
                }

                // Eliminar archivo procesado
                @unlink($file);

            } catch (Exception $e) {
                echo "❌ Error procesando señal: " . $e->getMessage() . "\n";
                @unlink($file);
            }
        }
    }

    /**
     * ✅ NUEVO: Difundir a todos los clientes (incluyendo emisor)
     */
    private function broadcastToAll($data)
    {
        $clients_notificados = 0;

        foreach ($this->clients as $client_socket) {
            if ($this->sendToClient($client_socket, $data)) {
                $clients_notificados++;
            }
        }

        $tipo = $data['tipo'] ?? 'notification';
        echo "📡 $tipo difundido a $clients_notificados clientes\n";
    }

    private function broadcastNotification($data, $sender_socket = null)
    {
        $clients_notificados = 0;

        foreach ($this->clients as $client_socket) {
            // No enviar de vuelta al emisor (si es una conexión cliente)
            if ($sender_socket && $client_socket === $sender_socket) {
                continue;
            }

            if ($this->sendToClient($client_socket, $data)) {
                $clients_notificados++;
            }
        }

        $tipo = $data['tipo'] ?? 'notification';
        echo "📡 $tipo difundido a $clients_notificados clientes\n";
    }

    private function sendToClient($socket, $data)
    {
        try {
            $message = json_encode($data);
            $encoded = $this->encodeWebSocketMessage($message);
            $result = socket_write($socket, $encoded);
            return $result !== false;
        } catch (Exception $e) {
            echo "❌ Error enviando a cliente: " . $e->getMessage() . "\n";
            return false;
        }
    }

    private function removeClient($socket)
    {
        $client_id = array_search($socket, $this->clients);
        if ($client_id !== false) {
            echo "🔌 Cliente #$client_id desconectado\n";
            unset($this->clients[$client_id]);
            socket_close($socket);
        }
    }

    private function cleanupClosedConnections()
    {
        // Verificar cada 30 segundos
        if (time() - $this->last_cleanup < 30)
            return;
        $this->last_cleanup = time();

        $removed = 0;
        foreach ($this->clients as $key => $socket) {
            if (!is_resource($socket) || !@socket_write($socket, '')) {
                echo "🧹 Limpiando cliente silencioso: #$key\n";
                unset($this->clients[$key]);
                @socket_close($socket);
                $removed++;
            }
        }

        if ($removed > 0) {
            echo "🧹 $removed clientes silenciosos removidos\n";
        }
    }

    /**
     * ✅ NUEVO: Limpiar archivos antiguos
     */
    private function cleanupOldFiles()
    {
        static $last_cleanup = 0;

        // Limpiar cada 10 minutos
        if (time() - $last_cleanup < 600)
            return;
        $last_cleanup = time();

        try {
            $temp_dir = sys_get_temp_dir();
            $pattern = $temp_dir . '/websocket_*';

            $files = glob($pattern);
            $now = time();
            $cleaned = 0;

            foreach ($files as $file) {
                if (is_file($file) && ($now - filemtime($file)) > 3600) { // 1 hora
                    if (@unlink($file)) {
                        $cleaned++;
                    }
                }
            }

            if ($cleaned > 0) {
                echo "🧹 $cleaned archivos antiguos limpiados\n";
            }

        } catch (Exception $e) {
            echo "❌ Error limpiando archivos: " . $e->getMessage() . "\n";
        }
    }

    private function createWebSocketHandshake($request)
    {
        $lines = explode("\r\n", $request);
        $headers = [];

        foreach ($lines as $line) {
            if (strpos($line, ':') !== false) {
                $parts = explode(':', $line, 2);
                $headers[trim($parts[0])] = trim($parts[1]);
            }
        }

        $key = $headers['Sec-WebSocket-Key'] ?? '';
        $accept = base64_encode(sha1($key . '258EAFA5-E914-47DA-95CA-C5AB0DC85B11', true));

        return "HTTP/1.1 101 Switching Protocols\r\n" .
            "Upgrade: websocket\r\n" .
            "Connection: Upgrade\r\n" .
            "Sec-WebSocket-Accept: $accept\r\n\r\n";
    }

    private function decodeWebSocketMessage($data)
    {
        if (strlen($data) < 2)
            return false;

        $bytes = unpack('C*', $data);
        $second_byte = $bytes[2];
        $masked = ($second_byte & 128) === 128;
        $payload_length = $second_byte & 127;

        $offset = 2;

        if ($payload_length === 126) {
            $payload_length = unpack('n', substr($data, $offset, 2))[1];
            $offset += 2;
        } elseif ($payload_length === 127) {
            $payload_length = unpack('J', substr($data, $offset, 8))[1];
            $offset += 8;
        }

        if ($masked) {
            $mask = substr($data, $offset, 4);
            $offset += 4;
            $payload = substr($data, $offset);

            $decoded = '';
            for ($i = 0; $i < strlen($payload); $i++) {
                $decoded .= $payload[$i] ^ $mask[$i % 4];
            }

            return $decoded;
        } else {
            return substr($data, $offset);
        }
    }

    private function encodeWebSocketMessage($message)
    {
        $length = strlen($message);

        if ($length < 126) {
            return chr(0x81) . chr($length) . $message;
        } elseif ($length < 65536) {
            return chr(0x81) . chr(126) . pack('n', $length) . $message;
        } else {
            return chr(0x81) . chr(127) . pack('J', $length) . $message;
        }
    }

    public function __destruct()
    {
        if ($this->socket) {
            socket_close($this->socket);
        }

        foreach ($this->clients as $client) {
            socket_close($client);
        }

        echo "\n🛑 Servidor WebSocket detenido\n";
    }
}

// ✅ INICIAR SERVIDOR
try {
    $server = new ServiciosWebSocketServer(8080);
    $server->run();
} catch (Exception $e) {
    echo "❌ Error fatal: " . $e->getMessage() . "\n";
}
?>