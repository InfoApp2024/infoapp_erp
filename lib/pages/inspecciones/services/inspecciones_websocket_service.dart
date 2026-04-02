import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/features/auth/data/auth_service.dart';
import 'package:infoapp/core/env/server_config.dart';

/// Servicio de Polling para Inspecciones
/// Consulta periódicamente al servidor para detectar cambios
class InspeccionesWebSocketService {
  static String get _pollingUrl => '${ServerConfig.instance.apiRoot()}/polling/check_updates.php';

  Timer? _pollingTimer;
  bool _isConnected = false;
  String? _lastCheckTimestamp;
  
  // Intervalo de consulta (10 segundos)
  static const Duration _pollingInterval = Duration(seconds: 10);

  // Streams para eventos
  final StreamController<Map<String, dynamic>> _inspeccionesCambiosController =
      StreamController<Map<String, dynamic>>.broadcast();

  final StreamController<bool> _connectionController =
      StreamController<bool>.broadcast();

  // Getters para los streams
  Stream<Map<String, dynamic>> get inspeccionesCambios =>
      _inspeccionesCambiosController.stream;
  Stream<bool> get connectionStatus => _connectionController.stream;
  bool get isConnected => _isConnected;

  /// Iniciar el servicio de Polling
  Future<void> conectar() async {
    if (_isConnected) return;
    _isConnected = true;
    _connectionController.add(true);
    
    // Establecer fecha inicial
    _lastCheckTimestamp = DateTime.now().toUtc().toIso8601String();

    // Iniciar el loop
    _startPolling();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (timer) {
      _checkUpdates();
    });
    
    // Primera verificación inmediata
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    if (!_isConnected) return;

    try {
      final rawToken = await AuthService.getToken();
      final url = Uri.parse('$_pollingUrl?last_check=${_lastCheckTimestamp ?? ""}&token=$rawToken&modulo=inspecciones');
      
      final token = await AuthService.getBearerToken();
      if (token == null) {
        return;
      }

      final headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          // Actualizar timestamp
          if (data['sync_timestamp'] != null) {
            _lastCheckTimestamp = data['sync_timestamp'];
          }

          if (data['has_updates'] == true) {
            // Emitir evento de actualización
            _inspeccionesCambiosController.add({
              'tipo': 'inspeccion_actualizada',
              'mensaje': 'Datos actualizados',
              'timestamp': DateTime.now().toIso8601String(),
            });
          }
        }
      }
    } catch (e) {
      // Ignore connection error in polling loop
    }
  }

  /// Detener el polling
  void desconectar() {
    _isConnected = false;
    _pollingTimer?.cancel();
    _connectionController.add(false);
  }

  /// Limpiar recursos
  void dispose() {
    desconectar();
    _inspeccionesCambiosController.close();
    _connectionController.close();
  }
}
