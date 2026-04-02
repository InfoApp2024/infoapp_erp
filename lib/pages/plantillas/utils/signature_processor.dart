import 'package:infoapp/pages/firmas/models/firma_model.dart';

/// Utilidad para inyectar firmas y nombres de responsables en el HTML
class SignatureProcessor {
  static String ensureDataUrl(String? base64) {
    if (base64 == null || base64.trim().isEmpty) return '';
    final cleaned = base64.trim();
    if (cleaned.startsWith('data:image')) return cleaned;
    if (cleaned.startsWith('http')) return cleaned;
    return 'data:image/png;base64,$cleaned';
  }

  static String _stripSrc(String attrs) {
    if (attrs.isEmpty) return attrs;
    return attrs
        .replaceAll(RegExp(r'\s+src\s*=\s*(?:"[^"]*"|' "'" r"[^']*'|[^\\s>]+)", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String _stripProblematicImgStyles(String attrs) {
    if (attrs.isEmpty) return attrs;
    return attrs
        .replaceAll(RegExp(r'\s+height\s*=\s*(?:"0[^"]*"|' "'" r"0[^']*'|0\b)", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+width\s*=\s*(?:"0[^"]*"|' "'" r"0[^']*'|0\b)", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+style\s*=\s*(?:"[^"]*"|' "'" r"[^']*')", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s+alt\s*=\s*(?:"[^"]*"|' "'" r"[^']*'|[^\s>]+)", caseSensitive: false), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();
  }

  static String injectFirmas(String html, FirmaModel? firma) {
    if (firma == null) return html;

    final staffData = ensureDataUrl(firma.firmaStaffBase64);
    final funcData = ensureDataUrl(firma.firmaFuncionarioBase64);
    
    // Estilos para asegurar visibilidad
    final styleCommon = 'height:80px !important; min-height:60px !important; max-height:120px !important; width:auto !important; object-fit:contain; display:block;';

    String out = html;

    // 1. Inyectar Staff (Ejecutado por)
    if (staffData.isNotEmpty) {
      // Reemplazo de imágenes por ALT
      out = out.replaceAllMapped(
        RegExp(r'<img([^>]*)alt="[^"]*Firma\s*(?:Staff|Entrega)[^"]*"([^>]*)>', caseSensitive: false),
        (m) {
          final combined = ('${m.group(1) ?? ''} ${m.group(2) ?? ''}').trim();
          final cleaned = _stripProblematicImgStyles(_stripSrc(combined));
          return '<img $cleaned alt="Firma Staff" src="$staffData" style="$styleCommon">';
        },
      );
      
      // Placeholders comunes
      final staffPlaceholders = [
        r'\{\{\s*firma_staff\s*\}\}', r'\[\s*firma_staff\s*\]',
        r'\{\{\s*firma_staff_imagen\s*\}\}', r'\[\s*firma_staff_imagen\s*\]',
        r'\{\{\s*firma_staff_base64\s*\}\}', r'\[\s*firma_staff_base64\s*\]',
        r'\{\{\s*firma_entrega_base64\s*\}\}', r'\[\s*firma_entrega_base64\s*\]',
      ];
      
      for (final p in staffPlaceholders) {
        if (p.contains('base64')) {
          out = out.replaceAll(RegExp(p, caseSensitive: false), staffData);
        } else {
          out = out.replaceAll(RegExp(p, caseSensitive: false), '<img alt="Firma Staff" src="$staffData" style="$styleCommon" />');
        }
      }
    }

    // 2. Inyectar Funcionario / Cliente (Recibido por)
    if (funcData.isNotEmpty) {
      out = out.replaceAllMapped(
        RegExp(r'<img([^>]*)alt="[^"]*Firma\s*(?:Funcionario|Recepci[oó]n|Cliente)[^"]*"([^>]*)>', caseSensitive: false),
        (m) {
          final combined = ('${m.group(1) ?? ''} ${m.group(2) ?? ''}').trim();
          final cleaned = _stripProblematicImgStyles(_stripSrc(combined));
          return '<img $cleaned alt="Firma Funcionario" src="$funcData" style="$styleCommon">';
        },
      );
      
      final funcPlaceholders = [
        r'\{\{\s*firma_funcionario\s*\}\}', r'\[\s*firma_funcionario\s*\]',
        r'\{\{\s*firma_funcionario_imagen\s*\}\}', r'\[\s*firma_funcionario_imagen\s*\]',
        r'\{\{\s*firma_funcionario_base64\s*\}\}', r'\[\s*firma_funcionario_base64\s*\]',
        r'\{\{\s*firma_recepcion_base64\s*\}\}', r'\[\s*firma_recepcion_base64\s*\]',
        r'\{\{\s*firma_cliente\s*\}\}', r'\[\s*firma_cliente\s*\]',
        r'\{\{\s*firma_cliente_imagen\s*\}\}', r'\[\s*firma_cliente_imagen\s*\]',
      ];
      
      for (final p in funcPlaceholders) {
        if (p.contains('base64')) {
          out = out.replaceAll(RegExp(p, caseSensitive: false), funcData);
        } else {
          out = out.replaceAll(RegExp(p, caseSensitive: false), '<img alt="Firma Funcionario" src="$funcData" style="$styleCommon" />');
        }
      }
    }

    // 3. Inyectar Nombres
    final staffNombre = (firma.staffNombre ?? '').trim();
    final funcNombre = (firma.funcionarioNombre ?? '').trim();

    if (staffNombre.isNotEmpty) {
      final staffNamePlaceholders = [
        r'\{\{\s*staff_nombre\s*\}\}', r'\[\s*staff_nombre\s*\]',
        r'\{\{\s*nombre_staff\s*\}\}', r'\[\s*nombre_staff\s*\]',
        r'\{\{\s*staffNombre\s*\}\}', r'\[\s*staffNombre\s*\]',
        r'\{\{\s*quien_ejecuta\s*\}\}', r'\[\s*quien_ejecuta\s*\]',
        r'\{\{\s*usuario_nombre_staff\s*\}\}', r'\[\s*usuario_nombre_staff\s*\]',
      ];
      for (final re in staffNamePlaceholders) {
        out = out.replaceAll(RegExp(re, caseSensitive: false), staffNombre);
      }
      out = out.replaceAllMapped(RegExp(r'(Ejecutado\s+por:\s*)([^\n<]+)', caseSensitive: false), (m) => '${m.group(1)}$staffNombre');
      out = out.replaceAllMapped(RegExp(r'(Executed\s+by:\s*)([^\n<]+)', caseSensitive: false), (m) => '${m.group(1)}$staffNombre');
    }

    if (funcNombre.isNotEmpty) {
      final funcNamePlaceholders = [
        r'\{\{\s*funcionario_nombre\s*\}\}', r'\[\s*funcionario_nombre\s*\]',
        r'\{\{\s*nombre_funcionario\s*\}\}', r'\[\s*nombre_funcionario\s*\]',
        r'\{\{\s*funcionarioNombre\s*\}\}', r'\[\s*funcionarioNombre\s*\]',
        r'\{\{\s*quien_recibe\s*\}\}', r'\[\s*quien_recibe\s*\]',
        r'\{\{\s*usuario_nombre_funcionario\s*\}\}', r'\[\s*usuario_nombre_funcionario\s*\]',
        r'\{\{\s*nombre_cliente\s*\}\}', r'\[\s*nombre_cliente\s*\]',
      ];
      for (final re in funcNamePlaceholders) {
        out = out.replaceAll(RegExp(re, caseSensitive: false), funcNombre);
      }
      out = out.replaceAllMapped(RegExp(r'(Recibido\s+por:\s*)([^\n<]+)', caseSensitive: false), (m) => '${m.group(1)}$funcNombre');
      out = out.replaceAllMapped(RegExp(r'(Received\s+by:\s*)([^\n<]+)', caseSensitive: false), (m) => '${m.group(1)}$funcNombre');
    }

    return out;
  }
}
