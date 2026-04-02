import 'package:flutter/services.dart';
import 'package:infoapp/core/utils/currency_utils.dart';

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Si el usuario está intentando borrar y el texto resultante sería igual al anterior
    // (por ejemplo, al borrar un punto separador), realizamos el borrado del dígito anterior
    if (newValue.text.length < oldValue.text.length) {
      // No necesitamos lógica especial aquí si CurrencyUtils maneja bien la limpieza
    }

    String formatted = CurrencyUtils.formatString(newValue.text);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
