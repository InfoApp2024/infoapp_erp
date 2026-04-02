import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/birthdays/data/birthday_model.dart';

class BirthdayService {
  static Future<List<BirthdayUser>> getBirthdays() async {
    try {
      final baseUrl = ServerConfig.instance.baseUrlFor('features/birthdays');
      final url = Uri.parse('$baseUrl/check_birthdays.php');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((e) => BirthdayUser.fromJson(e)).toList();
        }
      }
    } catch (e) {
      // Fail silently or log
      print('Error fetching birthdays: $e');
    }
    return [];
  }
}
