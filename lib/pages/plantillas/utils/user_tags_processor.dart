import 'package:infoapp/features/auth/data/auth_service.dart';

/// Utilidad para inyectar información del usuario actual en el HTML
class UserTagsProcessor {
  static Future<String> injectUserTags(String html) async {
    try {
      final user = await AuthService.getUserData();
      if (user == null) {
        String out = html;
        out = out.replaceAll(RegExp(r'\{\{\s*usuario_nombre_cliente\s*\}\}'), '');
        out = out.replaceAll(RegExp(r'\[\s*usuario_nombre_cliente\s*\]'), '');
        out = out.replaceAll(RegExp(r'\{\{\s*usuario_nit\s*\}\}'), '');
        out = out.replaceAll(RegExp(r'\[\s*usuario_nit\s*\]'), '');
        return out;
      }

      final nombre = (user['nombre_completo'] as String?)?.trim();
      final usuario = (user['usuario'] as String?)?.trim();
      final nit = (user['nit'] as String?)?.trim();

      String out = html;
      final nombreFinal = (nombre?.isNotEmpty == true) ? nombre! : (usuario ?? '');
      out = out.replaceAll(RegExp(r'\{\{\s*usuario_nombre_cliente\s*\}\}'), nombreFinal);
      out = out.replaceAll(RegExp(r'\[\s*usuario_nombre_cliente\s*\]'), nombreFinal);
      out = out.replaceAll(RegExp(r'\{\{\s*usuario_nit\s*\}\}'), nit ?? '');
      out = out.replaceAll(RegExp(r'\[\s*usuario_nit\s*\]'), nit ?? '');
      return out;
    } catch (_) {
      String out = html;
      out = out.replaceAll(RegExp(r'\{\{\s*usuario_nombre_cliente\s*\}\}'), '');
      out = out.replaceAll(RegExp(r'\[\s*usuario_nombre_cliente\s*\]'), '');
      out = out.replaceAll(RegExp(r'\{\{\s*usuario_nit\s*\}\}'), '');
      out = out.replaceAll(RegExp(r'\[\s*usuario_nit\s*\]'), '');
      return out;
    }
  }
}
