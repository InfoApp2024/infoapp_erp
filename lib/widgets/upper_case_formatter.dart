import 'package:flutter/services.dart';

/// Formateador que convierte todo el texto ingresado a MAYÚSCULAS.
/// - Mantiene la posición del cursor y selección.
/// - Aplica tanto al escribir como al pegar contenido.
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    return TextEditingValue(
      text: upper,
      selection: newValue.selection,
      composing: TextRange.empty,
    );
  }
}