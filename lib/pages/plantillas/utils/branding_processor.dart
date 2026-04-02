import 'package:infoapp/core/branding/branding_service.dart';

/// Utilidad para inyectar logos de branding en el HTML
class BrandingProcessor {
  static String injectLogo(String html) {
    final branding = BrandingService();
    final logoUrl = branding.logoUrl;

    if (logoUrl == null || logoUrl.isEmpty) {
      String out = html;
      final emptyImg = '<img alt="Logo Empresa" style="max-height:120px; object-fit:contain;" />';
      final removals = <RegExp, String>{
        RegExp(r'\{\{\s*logo_empresa\s*\}\}'): emptyImg,
        RegExp(r'\[\s*logo_empresa\s*\]'): emptyImg,
        RegExp(r'\{\{\s*logo_marca\s*\}\}'): emptyImg,
        RegExp(r'\[\s*logo_marca\s*\]'): emptyImg,
        RegExp(r'\{\{\s*branding_logo_url\s*\}\}'): emptyImg,
        RegExp(r'\[\s*branding_logo_url\s*\]'): emptyImg,
        RegExp(r'src\s*=\s*"\{\{\s*logo_empresa\s*\}\}"'): '',
        RegExp(r"src\s*=\s*'\{\{\s*logo_empresa\s*\}\}'"): '',
        RegExp(r'src\s*=\s*"\[\s*logo_empresa\s*\]"'): '',
        RegExp(r"src\s*=\s*'\[\s*logo_empresa\s*\]'"): '',
      };
      removals.forEach((r, v) => out = out.replaceAll(r, v));
      return out;
    }

    final replacements = <RegExp, String>{
      RegExp(r'\{\{\s*logo_empresa\s*\}\}'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'\[\s*logo_empresa\s*\]'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'\{\{\s*logo_marca\s*\}\}'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'\[\s*logo_marca\s*\]'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'\{\{\s*branding_logo_url\s*\}\}'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'\[\s*branding_logo_url\s*\]'):
          '<img alt="Logo Empresa" src="$logoUrl" style="max-height:120px; object-fit:contain;" />',
      RegExp(r'src\s*=\s*"\{\{\s*logo_empresa\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'\{\{\s*logo_empresa\s*\}\}'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"\[\s*logo_empresa\s*\]"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'\[\s*logo_empresa\s*\]'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"\{\{\s*logo_marca\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'\{\{\s*logo_marca\s*\}\}'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"\[\s*logo_marca\s*\]"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'\[\s*logo_marca\s*\]'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"\{\{\s*branding_logo_url\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'\{\{\s*branding_logo_url\s*\}\}'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"data:image\/png;base64,\{\{\s*branding_logo_url\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'data:image\/png;base64,\{\{\s*branding_logo_url\s*\}\}'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"data:image\/png;base64,\{\{\s*logo_empresa\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'data:image\/png;base64,\{\{\s*logo_empresa\s*\}\}'"): "src='$logoUrl'",
      RegExp(r'src\s*=\s*"data:image\/png;base64,\{\{\s*logo_marca\s*\}\}"'): 'src="$logoUrl"',
      RegExp(r"src\s*=\s*'data:image\/png;base64,\{\{\s*logo_marca\s*\}\}'"): "src='$logoUrl'",
    };

    String out = html;
    for (final e in replacements.entries) {
      out = out.replaceAll(e.key, e.value);
    }
    return out;
  }
}
