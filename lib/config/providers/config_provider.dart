import 'package:flutter/foundation.dart';

class ConfigProvider with ChangeNotifier {
  Map<String, dynamic> _config = {};

  Map<String, dynamic> get config => _config;

  void applyTemplate(Map<String, dynamic> template) {
    _config = template;
    notifyListeners();
  }

  void updateModule(String module, Map<String, dynamic> values) {
    final current = Map<String, dynamic>.from(_config[module] ?? {});
    current.addAll(values);
    _config[module] = current;
    notifyListeners();
  }

  Map<String, dynamic>? module(String module) {
    final value = _config[module];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  void reset() {
    _config = {};
    notifyListeners();
  }
}
