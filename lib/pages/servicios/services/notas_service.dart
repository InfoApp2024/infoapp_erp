import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';
import '../models/nota_model.dart';

class NotasService {
  Future<List<NotaModel>> listarNotas(int idServicio) async {
    final token = await AuthService.getToken();
    final url = Uri.parse(
      '${ServerConfig.instance.apiRoot()}/notas/listar.php?id_servicio=$idServicio',
    );

    final response = await http.get(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        final List<dynamic> notasJson = data['data'];
        return notasJson.map((json) => NotaModel.fromJson(json)).toList();
      } else {
        throw Exception(data['error'] ?? 'Error al listar notas');
      }
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  Future<void> crearNota(int idServicio, String nota) async {
    final token = await AuthService.getToken();
    final url = Uri.parse('${ServerConfig.instance.apiRoot()}/notas/crear.php');

    final response = await http.post(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id_servicio': idServicio, 'nota': nota}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Error al crear nota');
      }
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }

  Future<void> actualizarNota(int id, String nota) async {
    final token = await AuthService.getToken();
    final url = Uri.parse(
      '${ServerConfig.instance.apiRoot()}/notas/actualizar.php',
    );

    final response = await http.post(
      url,
      headers: {
        if (token != null) 'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'id': id, 'nota': nota}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] != true) {
        throw Exception(data['error'] ?? 'Error al actualizar nota');
      }
    } else {
      throw Exception('Error del servidor: ${response.statusCode}');
    }
  }
}
