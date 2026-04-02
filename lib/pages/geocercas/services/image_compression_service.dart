import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';

/// Servicio para comprimir imágenes antes de subirlas
class ImageCompressionService {
  /// Comprime una imagen a JPG con calidad 75%
  /// Reduce el tamaño típicamente en 70-80%
  static Future<File> compressImage(File originalFile) async {
    try {
      final dir = await getTemporaryDirectory();
      final targetPath = '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';

      if (kDebugMode) {
        final originalSize = await originalFile.length();
        print('📸 Comprimiendo imagen: ${(originalSize / 1024).toStringAsFixed(0)} KB');
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        quality: 75, // 75% de calidad (buen balance)
        format: CompressFormat.jpeg,
        minWidth: 1920, // Máximo ancho
        minHeight: 1080, // Máximo alto
        keepExif: false, // Eliminar metadatos EXIF para reducir tamaño
      );

      if (result == null) {
        throw Exception('Error al comprimir imagen');
      }

      final compressedFile = File(result.path);

      if (kDebugMode) {
        final compressedSize = await compressedFile.length();
        final reduction = ((1 - compressedSize / (await originalFile.length())) * 100).toStringAsFixed(0);
        print('✅ Imagen comprimida: ${(compressedSize / 1024).toStringAsFixed(0)} KB (reducción: $reduction%)');
      }

      return compressedFile;
    } catch (e) {
      if (kDebugMode) print('❌ Error al comprimir imagen: $e');
      // Si falla la compresión, devolver el archivo original
      return originalFile;
    }
  }

  /// Obtiene estadísticas de compresión
  static Future<Map<String, int>> getCompressionStats(
    File original,
    File compressed,
  ) async {
    final originalSize = await original.length();
    final compressedSize = await compressed.length();
    final reduction = ((1 - compressedSize / originalSize) * 100).round();

    return {
      'original_kb': (originalSize / 1024).round(),
      'compressed_kb': (compressedSize / 1024).round(),
      'reduction_percent': reduction,
    };
  }
}
