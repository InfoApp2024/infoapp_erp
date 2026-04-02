import 'package:intl/intl.dart';

class CurrencyUtils {
  static final _formatter = NumberFormat.decimalPattern('es_CO');

  /// Formatea un número a string con separadores de miles (puntos en es_CO)
  /// Ej: 5000000 -> "5.000.000"
  static String format(num? value) {
    if (value == null) return "0";
    return _formatter.format(value);
  }

  /// Limpia un string de separadores de miles y lo convierte a double
  /// Ej: "5.000.000" -> 5000000.0
  static double parse(String value) {
    if (value.isEmpty) return 0.0;
    // Eliminar puntos (separadores de miles en Colombia)
    String cleanValue = value.replaceAll('.', '');
    // Reemplazar coma decimal por punto si existe
    cleanValue = cleanValue.replaceAll(',', '.');
    return double.tryParse(cleanValue) ?? 0.0;
  }

  /// Formatea un string de entrada según escriben para el controlador
  static String formatString(String value) {
    if (value.isEmpty) return "";
    double parsed = parse(value);
    return format(parsed);
  }
}
