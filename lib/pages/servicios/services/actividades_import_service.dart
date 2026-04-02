import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:csv/csv.dart';
import 'actividades_api_service.dart';

class ActividadesImportService {
  /// Importar desde archivo
  static Future<Map<String, dynamic>> importarDesdeArchivo({
    required bool sobrescribir,
  }) async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx', 'xls', 'txt'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        throw Exception('No se seleccionó ningún archivo');
      }

      final file = result.files.first;
      final bytes = file.bytes;

      if (bytes == null) {
        throw Exception('No se pudo leer el archivo');
      }

      List<Map<String, dynamic>> actividades = [];

      // Procesar según el tipo de archivo
      switch (file.extension?.toLowerCase()) {
        case 'csv':
          actividades = await procesarCSV(bytes);
          break;
        case 'xlsx':
        case 'xls':
          actividades = await procesarExcel(bytes);
          break;
        case 'txt':
          actividades = await procesarTexto(bytes);
          break;
        default:
          throw Exception('Formato de archivo no soportado');
      }

      if (actividades.isEmpty) {
        throw Exception('No se encontraron actividades en el archivo');
      }

      // Enviar al servidor
      return await ActividadesApiService.importarActividades(
        actividades,
        sobrescribir: sobrescribir,
      );
    } catch (e) {
      // print('❌ Error importando archivo: $e');
      throw Exception('Error al importar archivo: $e');
    }
  }

  /// Procesar archivo CSV
  static Future<List<Map<String, dynamic>>> procesarCSV(List<int> bytes, {int? sistemaId}) async {
    try {
      final String content = utf8.decode(bytes);
      final List<List<dynamic>> rows = const CsvToListConverter(
        eol: '\n',
        shouldParseNumbers: false,
      ).convert(content);

      final List<Map<String, dynamic>> actividades = [];

      for (int i = 0; i < rows.length; i++) {
        if (rows[i].isNotEmpty) {
          // Columna 0: Actividad
          final String actividad = rows[i][0].toString().trim();

          // Omitir encabezados comunes
          if (i == 0 && esEncabezado(actividad)) {
            continue;
          }

          if (actividad.isNotEmpty) {
            // Columna 1: Horas (opcional)
            double cantHora = 0.0;
            if (rows[i].length > 1) {
              cantHora = double.tryParse(rows[i][1].toString()) ?? 0.0;
            }

            // Columna 2: Num Técnicos (opcional)
            int numTecnicos = 0;
            if (rows[i].length > 2) {
              numTecnicos = int.tryParse(rows[i][2].toString()) ?? 0;
            }

            actividades.add({
              'actividad': actividad,
              'cant_hora': cantHora,
              'num_tecnicos': numTecnicos,
              'sistema_id': sistemaId, // ✅ INYECTADO
            });
          }
        }
      }

      return actividades;
    } catch (e) {
      throw Exception('Error procesando CSV: $e');
    }
  }

  /// Procesar archivo Excel
  static Future<List<Map<String, dynamic>>> procesarExcel(
    List<int> bytes, {int? sistemaId}
  ) async {
    try {
      final excel = Excel.decodeBytes(bytes);
      final List<Map<String, dynamic>> actividades = [];

      // Procesar la primera hoja
      for (final table in excel.tables.keys) {
        final sheet = excel.tables[table];
        if (sheet == null) continue;

        for (int rowIndex = 0; rowIndex < sheet.maxRows; rowIndex++) {
          final row = sheet.row(rowIndex);
          if (row.isNotEmpty && row[0] != null) {
            final String actividad = row[0]?.value?.toString().trim() ?? '';

            // Omitir encabezados comunes
            if (rowIndex == 0 && esEncabezado(actividad)) {
              continue;
            }

            if (actividad.isNotEmpty) {
              // Columna 1: Horas
              double cantHora = 0.0;
              if (row.length > 1 && row[1] != null) {
                cantHora =
                    double.tryParse(row[1]?.value.toString() ?? '') ?? 0.0;
              }

              // Columna 2: Técnicos
              int numTecnicos = 0;
              if (row.length > 2 && row[2] != null) {
                numTecnicos = int.tryParse(row[2]?.value.toString() ?? '') ?? 0;
              }

               actividades.add({
                'actividad': actividad,
                'cant_hora': cantHora,
                'num_tecnicos': numTecnicos,
                'sistema_id': sistemaId, // ✅ INYECTADO
              });
            }
          }
        }

        break; // Solo procesar la primera hoja
      }

      return actividades;
    } catch (e) {
      throw Exception('Error procesando Excel: $e');
    }
  }

  /// Procesar archivo de texto (una actividad por línea)
  static Future<List<Map<String, dynamic>>> procesarTexto(
    List<int> bytes, {int? sistemaId}
  ) async {
    try {
      final String content = utf8.decode(bytes);
      final List<String> lines = content.split('\n');
      final List<Map<String, dynamic>> actividades = [];

      for (int i = 0; i < lines.length; i++) {
        final String actividad = lines[i].trim();

        // Omitir líneas vacías
        if (actividad.isEmpty) continue;

        // Omitir encabezados comunes
        if (i == 0 && esEncabezado(actividad)) {
          continue;
        }

        // Asumimos solo nombre para TXT simple
        actividades.add({
          'actividad': actividad,
          'cant_hora': 0.0,
          'num_tecnicos': 0,
          'sistema_id': sistemaId, // ✅ INYECTADO
        });
      }

      return actividades;
    } catch (e) {
      throw Exception('Error procesando texto: $e');
    }
  }

  /// Importar desde texto pegado
  static Future<Map<String, dynamic>> importarDesdeTexto({
    required String texto,
    required bool sobrescribir,
    int? sistemaId, // ✅ AGREGADO
  }) async {
    try {
      if (texto.trim().isEmpty) {
        throw Exception('El texto está vacío');
      }

      // Separar por líneas
      final List<String> lineas = texto.split('\n');
      final List<Map<String, dynamic>> actividades = [];

      for (final linea in lineas) {
        final actividad = linea.trim();
        if (actividad.isNotEmpty) {
          // Permitir formato "Nombre, Horas, Tecnicos" si el usuario lo pega así
          if (actividad.contains(',')) {
            final parts = actividad.split(',');
            final name = parts[0].trim();
            final horas =
                parts.length > 1
                    ? double.tryParse(parts[1].trim()) ?? 0.0
                    : 0.0;
            final tecnicos =
                parts.length > 2 ? int.tryParse(parts[2].trim()) ?? 0 : 0;
            if (name.isNotEmpty) {
              actividades.add({
                'actividad': name,
                'cant_hora': horas,
                'num_tecnicos': tecnicos,
                'sistema_id': sistemaId, // ✅ INYECTADO
              });
            }
          } else {
            actividades.add({
              'actividad': actividad,
              'cant_hora': 0.0,
              'num_tecnicos': 0,
              'sistema_id': sistemaId, // ✅ INYECTADO
            });
          }
        }
      }

      if (actividades.isEmpty) {
        throw Exception('No se encontraron actividades válidas');
      }

      // Enviar al servidor
      return await ActividadesApiService.importarActividades(
        actividades,
        sobrescribir: sobrescribir,
      );
    } catch (e) {
      // print('❌ Error importando texto: $e');
      throw Exception('Error al importar texto: $e');
    }
  }

  /// Generar plantilla CSV
  static Future<String> generarPlantillaCSV() async {
    final List<List<String>> rows = [
      ['# INSTRUCCIONES DE IMPORTACIÓN:'],
      ['# 1. No modifique los encabezados de las columnas.'],
      ['# 2. Las columnas con * son obligatorias.'],
      ['# 3. Este archivo soporta tildes y caracteres especiales (UTF-8).'],
      ['# 4. Elimine estas líneas de instrucciones si lo desea, pero no es necesario (el sistema las ignorará).'],
      [],
      ['Actividad*', 'Horas estimadas', 'Nº Técnicos'], // Encabezado
      ['Cambio de aceite y filtro', '1.5', '1'],
      ['Revisión de frenos', '0.75', '1'],
      ['Alineación y balanceo', '1.0', '1'],
      ['Diagnóstico electrónico', '0.5', '1'],
      ['Cambio de bujías', '1.0', '1'],
      ['Revisión de suspensión', '2.0', '2'],
      ['Cambio de batería', '0.3', '1'],
      ['Revisión general preventiva', '3.0', '2'],
    ];

    return const ListToCsvConverter().convert(rows);
  }

  /// Verificar si es un encabezado común
  static bool esEncabezado(String texto) {
    if (texto.startsWith('#')) return true; // Ignorar comentarios e instrucciones

    final encabezados = [
      'actividad',
      'actividades',
      'nombre',
      'descripcion',
      'descripción',
      'activity',
      'activities',
      'name',
      'horas',
      'horas estimadas',
      'tecnicos',
      'nº técnicos',
      'n tecnicos',
    ];

    final textoLower = texto.toLowerCase();
    return encabezados.any((h) => textoLower.contains(h));
  }

  /// Validar lista de actividades
  static Map<String, dynamic> validarActividades(
    List<Map<String, dynamic>> actividades,
  ) {
    final List<String> validas = [];
    final List<String> invalidas = [];
    final Set<String> duplicadas = {};
    final Set<String> vistas = {};

    for (final item in actividades) {
      final String actividad = item['actividad'] ?? '';
      final actividadTrim = actividad.trim();

      // Verificar duplicados
      if (vistas.contains(actividadTrim.toLowerCase())) {
        duplicadas.add(actividadTrim);
        continue;
      }
      vistas.add(actividadTrim.toLowerCase());

      // Validar longitud
      if (actividadTrim.length < 3) {
        invalidas.add('$actividadTrim (muy corta)');
      } else if (actividadTrim.length > 255) {
        invalidas.add('$actividadTrim (muy larga)');
      } else {
        // Validar valores numéricos si es necesario, pero por ahora aceptamos 0
        validas.add(actividadTrim);
      }
    }

    return {
      'validas': validas,
      'invalidas': invalidas,
      'duplicadas': duplicadas.toList(),
      'total': actividades.length,
    };
  }
}
