import 'package:infoapp/core/env/server_config.dart';

/// Utilidad para gestionar la transformación de URLs relativas a absolutas
class UrlProcessor {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  static String absolutizeUrls(String html) {
    String out = html;

    // Uploads generales
    out = out.replaceAllMapped(
      RegExp(r'src="(\.\.\/uploads\/[^\"]+)"'),
      (m) => 'src="$_baseUrl/${m.group(1)!.replaceFirst('../', '')}"',
    );
    out = out.replaceAllMapped(
      RegExp(r'src="(\/uploads\/[^\"]+)"'),
      (m) => 'src="$_baseUrl${m.group(1)}"',
    );
    out = out.replaceAllMapped(
      RegExp(r"src='(\/uploads\/[^']+)'"),
      (m) => "src='$_baseUrl${m.group(1)}'",
    );
    out = out.replaceAllMapped(
      RegExp(r'src="(uploads\/[^\"]+)"'),
      (m) => 'src="$_baseUrl/${m.group(1)}"',
    );
    out = out.replaceAllMapped(
      RegExp(r"src='(uploads\/[^']+)'"),
      (m) => "src='$_baseUrl/${m.group(1)}'",
    );

    // Archivos de campos
    out = out.replaceAllMapped(
      RegExp(r'src="((?:\.\.\/)?ver_archivo_campo\.php\?[^\"]+)"'),
      (m) => 'src="$_baseUrl/core/fields/${m.group(1)!.replaceFirst('../', '')}"',
    );
    out = out.replaceAllMapped(
      RegExp(r"src='((?:\.\.\/)?ver_archivo_campo\.php\?[^']+)'"),
      (m) => "src='$_baseUrl/core/fields/${m.group(1)!.replaceFirst('../', '')}'",
    );

    // Imágenes de servicios
    out = out.replaceAllMapped(
      RegExp(r'src="((?:\.\.\/)?servicio\/ver_imagen\.php\?[^\"]+)"'),
      (m) => 'src="$_baseUrl/${m.group(1)!.replaceFirst('../', '')}"',
    );
    out = out.replaceAllMapped(
      RegExp(r"src='((?:\.\.\/)?servicio\/ver_imagen\.php\?[^']+)'"),
      (m) => "src='$_baseUrl/${m.group(1)!.replaceFirst('../', '')}'",
    );

    // Firmas específicas
    out = out.replaceAllMapped(
      RegExp(r'src="(\.\.\/uploads\/firmas\/[^\"]+)"'),
      (m) => 'src="$_baseUrl/${m.group(1)!.replaceFirst('../', '')}"',
    );
    out = out.replaceAllMapped(
      RegExp(r'src="(\/uploads\/firmas\/[^\"]+)"'),
      (m) => 'src="$_baseUrl${m.group(1)}"',
    );
    out = out.replaceAllMapped(
      RegExp(r'src="(uploads\/firmas\/[^\"]+)"'),
      (m) => 'src="$_baseUrl/${m.group(1)}"',
    );
    out = out.replaceAllMapped(
      RegExp(r"src='(\/uploads\/firmas\/[^']+)'"),
      (m) => "src='$_baseUrl${m.group(1)}'",
    );
    out = out.replaceAllMapped(
      RegExp(r"src='(uploads\/firmas\/[^']+)'"),
      (m) => "src='$_baseUrl/${m.group(1)}'",
    );

    return out;
  }
}
