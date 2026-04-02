import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

class AiConfigService extends ChangeNotifier {
  static final AiConfigService _instance = AiConfigService._internal();
  factory AiConfigService() => _instance;
  AiConfigService._internal();

  bool _isAiEnabled = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  bool get isAiEnabled => _isAiEnabled;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;

  /// Consulta el servidor para verificar si hay una API Key configurada.
  Future<void> checkConfig() async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final token = await AuthService.getToken();
      final baseUrl = ServerConfig.instance.apiRoot();
      final url = '$baseUrl/chatbot/get_settings.php';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          // El endpoint devuelve 'has_key' directamente o podemos inferirlo de masked_key
          _isAiEnabled = data['has_key'] == true || (data['masked_key'] != null && data['masked_key'].toString().isNotEmpty);
        } else {
          _isAiEnabled = false;
        }
      } else {
        _isAiEnabled = false;
      }
    } catch (e) {
      debugPrint('Error comprobando configuración de IA: $e');
      _isAiEnabled = false;
    } finally {
      _isLoading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Permite actualizar el estado de forma manual (ej: al guardar en la pantalla de ajustes)
  void updateStatus(bool enabled) {
    if (_isAiEnabled != enabled) {
      _isAiEnabled = enabled;
      _isInitialized = true;
      notifyListeners();
    }
  }
}
