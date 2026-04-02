import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:io' as io;

/// Servicio de conectividad mínimo (sin connectivity_plus)
/// - Mobile/desktop: usa DNS lookup del host
/// - Web: hace una petición HTTP ligera
class ConnectivityService {
  ConnectivityService._internal();
  static final ConnectivityService instance = ConnectivityService._internal();

  final _statusController = StreamController<bool>.broadcast();
  Stream<bool> get status$ => _statusController.stream;

  bool _isRunning = false;
  bool _isConnected = true;
  Timer? _timer;

  // Host principal a verificar
  static const String _host = 'migracion-infoapp.novatechdevelopment.com';

  void start({Duration interval = const Duration(seconds: 30)}) {
    if (_isRunning) return;
    _isRunning = true;

    // Chequeo inmediato y luego periódico
    _checkAndEmit();
    _timer = Timer.periodic(interval, (_) => _checkAndEmit());
  }

  Future<void> _checkAndEmit() async {
    final ok = await checkNow();
    if (ok != _isConnected) {
      _isConnected = ok;
      _statusController.add(ok);
    }
  }

  Future<bool> checkNow() async {
    try {
      if (kIsWeb) {
        // Web: evitar CORS y ruido usando un recurso local con cache busting.
        final ts = DateTime.now().millisecondsSinceEpoch;
        final uri = Uri.parse('version.json?nocache=$ts');
        final r = await http
            .get(uri, headers: {'Cache-Control': 'no-cache'})
            .timeout(const Duration(seconds: 3));
        return r.statusCode >= 200 && r.statusCode < 500;
      }

      // Mobile/Desktop: verificación por DNS del host principal.
      final result = await io.InternetAddress.lookup(_host)
          .timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _isRunning = false;
    _statusController.close();
  }
}
