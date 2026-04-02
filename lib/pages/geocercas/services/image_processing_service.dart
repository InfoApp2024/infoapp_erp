import 'dart:io';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class ImageProcessingService {
  /// Procesa una imagen: redimensiona, aplica marca de agua y comprime.
  static Future<File?> procesarEvidencia({
    required File originalFile,
    required String nombreLugar,
    required String tipoEvento,
    double? latitud,
    double? longitud,
  }) async {
    try {
      // 1. Leer la imagen
      final Uint8List bytes = await originalFile.readAsBytes();
      img.Image? image = img.decodeImage(bytes);
      
      if (image == null) return null;

      // 2. Redimensionar si es muy grande (max 1200px lado mayor)
      if (image.width > 1200 || image.height > 1200) {
        if (image.width > image.height) {
          image = img.copyResize(image, width: 1200);
        } else {
          image = img.copyResize(image, height: 1200);
        }
      }

      // 3. Preparar texto de la marca de agua
      final now = DateTime.now();
      final dateStr = DateFormat('dd/MM/yyyy HH:mm:ss').format(now);
      final coordsStr = (latitud != null && longitud != null) 
          ? '${latitud.toStringAsFixed(5)}, ${longitud.toStringAsFixed(5)}'
          : '';
      
      final watermarkText = '$nombreLugar - $tipoEvento\n$dateStr\n$coordsStr';

      // 4. Dibujar marca de agua (fondo semitransparente para legibilidad)
      final font = img.arial24;
      final x = 20;
      final y = image.height - 100;

      // Dibujar un pequeño rectángulo oscuro de fondo para el texto
      img.fillRect(
        image,
        x1: x - 5,
        y1: y - 5,
        x2: x + 400,
        y2: y + 80,
        color: img.ColorRgba8(0, 0, 0, 150),
      );

      img.drawString(
        image,
        watermarkText,
        font: font,
        x: x,
        y: y,
        color: img.ColorRgba8(255, 255, 255, 255),
      );

      // 5. Guardar temporalmente como JPG
      final directory = await getTemporaryDirectory();
      final tempPath = '${directory.path}/processed_${now.millisecondsSinceEpoch}.jpg';
      final processedBytes = img.encodeJpg(image, quality: 85);
      
      File tempFile = File(tempPath);
      await tempFile.writeAsBytes(processedBytes);

      // 6. Compresión final agresiva para ahorro de datos
      final compressedPath = '${directory.path}/final_${now.millisecondsSinceEpoch}.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        tempFile.absolute.path,
        compressedPath,
        quality: 70,
        minWidth: 1024,
        minHeight: 1024,
      );

      // Limpiar archivo temporal intermedio
      if (await tempFile.exists()) await tempFile.delete();

      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Error al procesar imagen: $e');
      return null;
    }
  }
}
