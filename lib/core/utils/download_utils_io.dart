import 'dart:io';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

Future<void> saveBytes(String filename, List<int> bytes, {String? mimeType}) async {
  // Write to system temp and share; avoids storage permissions and works on Android/iOS/desktop.
  final tempDir = Directory.systemTemp;
  final file = File('${tempDir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
}

Future<void> saveText(String filename, String text, {String? mimeType}) async {
  final tempDir = Directory.systemTemp;
  final file = File('${tempDir.path}/$filename');
  await file.writeAsString(text, flush: true, encoding: utf8);
  await OpenFilex.open(file.path);
}

Future<void> openExternalUrl(String url) async {
  final uri = Uri.parse(url);
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    throw 'No se pudo abrir la URL: $url';
  }
}
