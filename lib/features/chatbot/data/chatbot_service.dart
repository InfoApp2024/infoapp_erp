import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/chat_message.dart';

class ChatbotService {
  Future<String?> getToken() async {
    return await AuthService.getToken();
  }

  String get _baseUrl => ServerConfig.instance.apiRoot();

  Future<List<ChatMessage>> getHistory() async {
    try {
      final token = await getToken();
      final url = '$_baseUrl/chatbot/get_history.php';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['messages'] != null) {
          final List<dynamic> history = data['messages'];
          return history.map((msg) => ChatMessage.fromJson(msg)).toList();
        }
      }
      return [];
    } catch (e) {
      // Log error or rethrow
      return [];
    }
  }

  Future<String> sendMessage(String text) async {
    try {
      final token = await getToken();
      final url = '$_baseUrl/chatbot/chat.php';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'message': text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] ?? 'Lo siento, no entendí eso.';
      } else {
        return 'Error del servidor: ${response.statusCode}';
      }
    } catch (e) {
      return 'Error de conexión: $e';
    }
  }

  Future<void> clearHistory() async {
      // Implement if there's an API for it, usually just local clear for now based on UI code.
      // But maybe we should add an endpoint call here if one existed.
      // For now, no API call was present in original code for clearing history (it just cleared local list).
  }
}
