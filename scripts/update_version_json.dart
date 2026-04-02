import 'dart:io';

void main() async {
  // 1. Leer la versión del pubspec.yaml
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    print('Error: No se encontró pubspec.yaml');
    exit(1);
  }

  final lines = pubspecFile.readAsLinesSync();
  String? version;

  for (final line in lines) {
    if (line.trim().startsWith('version:')) {
      version = line.split(':')[1].trim();
      break;
    }
  }

  if (version == null) {
    print('Error: No se encontró la versión en pubspec.yaml');
    exit(1);
  }

  print('📦 Versión detectada: $version');

  // 2. Actualizar web/version.json
  final webDir = Directory('web');
  if (!webDir.existsSync()) {
    webDir.createSync();
  }

  final jsonContent = '''
{
    "version": "$version"
}
''';

  final versionFile = File('web/version.json');
  versionFile.writeAsStringSync(jsonContent);
  print('✅ web/version.json actualizado a la versión: $version');

  // 3. Actualizar lib/core/version/app_version.dart
  final versionDir = Directory('lib/core/version');
  if (!versionDir.existsSync()) {
    versionDir.createSync(recursive: true);
  }

  final dartContent = '''// Archivo generado automáticamente - NO EDITAR MANUALMENTE
const String kAppVersion = '$version';
''';

  final dartFile = File('lib/core/version/app_version.dart');
  dartFile.writeAsStringSync(dartContent);
  print('✅ lib/core/version/app_version.dart actualizado a la versión: $version');

  // 4. Inyectar la versión en web/index.html
  // Busca la línea con INFOAPP_BUILD_VERSION entre los marcadores VERSION_LINE_START / VERSION_LINE_END
  final indexFile = File('web/index.html');
  if (!indexFile.existsSync()) {
    print('⚠️  web/index.html no encontrado, omitiendo inyección de versión.');
  } else {
    final lines = indexFile.readAsLinesSync();
    bool inBlock = false;
    bool replaced = false;
    final newLines = <String>[];

    for (final line in lines) {
      if (line.contains('// VERSION_LINE_START')) {
        inBlock = true;
        newLines.add(line);
        continue;
      }
      if (line.contains('// VERSION_LINE_END')) {
        inBlock = false;
        newLines.add(line);
        continue;
      }
      if (inBlock && line.contains('INFOAPP_BUILD_VERSION')) {
        // Reemplazar la línea con la nueva versión
        newLines.add("    var INFOAPP_BUILD_VERSION = '$version';");
        replaced = true;
      } else {
        newLines.add(line);
      }
    }

    if (replaced) {
      indexFile.writeAsStringSync(newLines.join('\n'));
      print('✅ web/index.html actualizado → INFOAPP_BUILD_VERSION = \'$version\'');
    } else {
      print('⚠️  No se encontró VERSION_LINE_START/END en web/index.html.');
    }
  }


  print('');
  print('🚀 Todo actualizado correctamente. Puedes hacer flutter build web ahora.');
}
