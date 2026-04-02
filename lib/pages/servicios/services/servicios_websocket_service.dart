import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../../features/auth/data/auth_service.dart';
import '../models/servicio_evento_model.dart';

/// Servicio de Polling (Reemplazo de WebSocket)
/// Consulta periódicamente al servidor para ver si hay cambios
class ServiciosWebSocketService {
  static const String _pollingUrl =
      'https://migracion-infoapp.novatechdevelopment.com/API_Infoapp/polling/check_updates.php';

  Timer? _pollingTimer;
  bool _isConnected = false;
  String? _lastCheckTimestamp;
  
  // Intervalo de consulta (10 segundos es un buen balance)
  static const Duration _pollingInterval = Duration(seconds: 10);

  // Streams para diferentes tipos de eventos
  final StreamController<ServicioEventoModel> _serviciosCambiosController =
      StreamController<ServicioEventoModel>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // Getters para los streams
  Stream<ServicioEventoModel> get serviciosCambios =>
      _serviciosCambiosController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;

  /// Iniciar el servicio de Polling (Equivalente a conectar)
  Future<void> conectar() async {
    if (_isConnected) return;

    // Silently start polling service
    _isConnected = true;
    _connectionController.add(true);
    
    // Establecer fecha inicial para no traer historial antiguo
    // Usamos el formato MySQL datetime
    _lastCheckTimestamp = DateTime.now().toUtc().toIso8601String();

    // Iniciar el loop
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _checkUpdates();
    });
    
    // Hacer una primera verificación inmediata
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    if (!_isConnected) return;

    try {
      final rawToken = await AuthService.getToken();
      final url = Uri.parse('$_pollingUrl?last_check=${_lastCheckTimestamp ?? ""}&token=$rawToken');
      
      final token = await AuthService.getBearerToken();
      if (token == null) {
        return;
      }
      
      final headers = {
          'Authorization': token,
          'Content-Type': 'application/json',
      };

      final response = await http.get(
        url,
        headers: headers,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Actualizar el timestamp para la próxima consulta
          if (data['sync_timestamp'] != null) {
            _lastCheckTimestamp = data['sync_timestamp'];
          }

          if (data['has_updates'] == true) {
            // Si hay actualizaciones, emitimos un evento genérico de actualización
            // para que la UI recargue la lista
            _serviciosCambiosController.add(ServicioEventoModel(
              tipo: 'servicio_actualizado', // Tipo genérico para forzar recarga
              mensaje: 'Datos actualizados',
              timestamp: DateTime.now(),
            ));
          }
        }
      } else {
        // Silently handle error
      }
    } catch (e) {
      // Ignore connection error in polling loop
    }
  }

  /// Detener el polling (Desconectar)
  void desconectar() {
    _isConnected = false;
    _pollingTimer?.cancel();
    _connectionController.add(false);
  }

  /// Métodos legacy para mantener compatibilidad si se llaman desde fuera
  void  notificarCambioLocal(String tipo, Map<String, dynamic> data) {
    // En polling puro, el cliente no suele notificar por aquí, 
    // sino que hace POST a la API y luego el polling detecta el cambio.
    // Solo lo dejamos vacío para no romper código existente.
  }

  /// Limpiar recursos
  void dispose() {
    desconectar();
    _serviciosCambiosController.close();
    _connectionController.close();
  }
}
