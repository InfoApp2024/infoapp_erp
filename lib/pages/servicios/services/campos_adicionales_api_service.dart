import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:infoapp/utils/connectivity_service.dart';
import '../models/campo_adicional_model.dart';
import 'package:infoapp/core/env/server_config.dart';
import 'package:infoapp/features/auth/data/auth_service.dart';

/// Servicio para manejar campos adicionales dinámicos
class CamposAdicionalesApiService {
  static String get _baseUrl => ServerConfig.instance.apiRoot();

  /// Obtener campos adicionales con valores para múltiples servicios (batch)
  static Future<Map<int, List<CampoAdicionalModel>>> obtenerCamposBatch({
    required List<int> servicioIds,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print('📡 [CAMPOS_ADICIONALES] Batch para servicios: ${servicioIds.join(",")}');
      final isOnline = await ConnectivityService.instance.checkNow();
      if (!isOnline) {
        final prefs = await SharedPreferences.getInstance();
        final Map<int, List<CampoAdicionalModel>> camposPorServicio = {};
        for (final sid in servicioIds) {
          final raw = prefs.getString('campos_adicionales_valores_$sid');
          if (raw == null || raw.isEmpty) continue;
          try {
            final decoded = jsonDecode(raw);
            final list =
                (decoded as List)
                    .map(
                      (e) => CampoAdicionalModel(
                        id: (e as Map)['campo_id'] ?? (e)['id'] ?? 0,
                        nombreCampo: (e)['nombre_campo'] ?? '',
                        tipoCampo: (e)['tipo_campo'] ?? '',
                        obligatorio: ((e)['obligatorio'] ?? 0) == 1,
                        modulo: ((e)['modulo'] ?? '').toString(),
                        estadoMostrar: (e)['estado_mostrar']?.toString(),
                        valor: (e)['valor'],
                      ),
                    )
                    .toList();
            if (list.isNotEmpty) {
              camposPorServicio[sid] = list;
            }
          } catch (_) {}
        }
        return camposPorServicio;
      }

      final uri = Uri.parse(
        '$_baseUrl/core/fields/obtener_valores_campos_adicionales_batch.php',
      );

      final response = await http.post(
        uri,
        headers: _headers,
        body: jsonEncode({'servicio_ids': servicioIds, 'modulo': modulo}),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['data'] != null && result['data'] is Map) {
          final Map<int, List<CampoAdicionalModel>> camposPorServicio = {};
          final prefs = await SharedPreferences.getInstance();
          (result['data'] as Map).forEach((sid, camposList) {
            final int servicioId = int.tryParse(sid.toString()) ?? 0;
            final List<CampoAdicionalModel> campos =
                (camposList as List).map((json) {
                  final moduloJson = (json['modulo'] ?? '').toString().trim();
                  // Si el backend devuelve módulo vacío:
                  // - Asignar 'servicios' SOLO cuando el contexto sea Servicios
                  // - En otros contextos (Equipos/otros), conservar vacío para no mezclar
                  // No forzar 'servicios' cuando el backend devuelve vacío; mantener tal cual
                  final moduloAsignado = moduloJson;
                  return CampoAdicionalModel(
                    id: json['campo_id'] ?? 0,
                    nombreCampo: json['nombre_campo'] ?? '',
                    tipoCampo: json['tipo_campo'] ?? '',
                    obligatorio: (json['obligatorio'] ?? 0) == 1,
                    modulo: moduloAsignado,
                    estadoMostrar: null,
                    valor: json['valor'],
                  );
                }).toList();
            camposPorServicio[servicioId] = campos;
            try {
              final toSave =
                  campos
                      .map(
                        (c) => {
                          'campo_id': c.id,
                          'nombre_campo': c.nombreCampo,
                          'tipo_campo': c.tipoCampo,
                          'obligatorio': c.obligatorio ? 1 : 0,
                          'modulo': c.modulo,
                          'estado_mostrar': c.estadoMostrar,
                          'valor': c.valor,
                        },
                      )
                      .toList();
              prefs.setString(
                'campos_adicionales_valores_$servicioId',
                jsonEncode(toSave),
              );
            } catch (_) {}
          });
          //           print('✅ [CAMPOS_ADICIONALES] Batch: ${camposPorServicio.length} servicios procesados');
          return camposPorServicio;
        } else {
          throw Exception('Respuesta inválida del batch');
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [CAMPOS_ADICIONALES] Error batch: $e');
      return {};
    }
  }

  // Headers comunes
  static const Map<String, String> _headers = {
    'Content-Type': 'application/json; charset=utf-8',
    'Accept': 'application/json',
    'User-Agent': 'Flutter App',
  };

  /// ✅ NUEVO: Obtener campos disponibles por estado
  static Future<List<CampoAdicionalModel>> obtenerCamposPorEstado({
    required int estadoId,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print('📡 [CAMPOS_ADICIONALES] Obteniendo campos para estado $estadoId');
      final isOnline = await ConnectivityService.instance.checkNow();
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'campos_config_estado_${estadoId}_$modulo';
      if (!isOnline) {
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final camposData = jsonDecode(raw) as List<dynamic>;
            return camposData.map((json) {
              final moduloJson = (json['modulo'] ?? '').toString().trim();
              final moduloAsignado = moduloJson;
              return CampoAdicionalModel(
                id: int.tryParse(json['id'].toString()) ?? 0,
                nombreCampo: json['nombre_campo'] ?? '',
                tipoCampo: json['tipo_campo'] ?? '',
                obligatorio: (json['obligatorio'] ?? 0) == 1,
                modulo: moduloAsignado,
                estadoMostrar: json['estado_mostrar']?.toString(),
                valor: null,
              );
            }).toList();
          } catch (_) {}
        }
        return [];
      }

      final uri = Uri.parse(
        '$_baseUrl/core/fields/obtener_campos_por_estado.php',
      ).replace(
        queryParameters: {'estado_id': estadoId.toString(), 'modulo': modulo},
      );

      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final List<dynamic> camposData = result['campos'] ?? [];

          //           print('✅ [CAMPOS_ADICIONALES] ${camposData.length} campos obtenidos');

          final list =
              camposData.map((json) {
                final moduloJson = (json['modulo'] ?? '').toString().trim();
                // Si el backend devuelve módulo vacío:
                // - Asignar 'servicios' SOLO cuando el contexto sea Servicios
                // - En otros contextos (Equipos/otros), conservar vacío
                // No forzar 'servicios' cuando el backend devuelve vacío; mantener tal cual
                final moduloAsignado = moduloJson;
                return CampoAdicionalModel(
                  id: int.tryParse(json['id'].toString()) ?? 0,
                  nombreCampo: json['nombre_campo'] ?? '',
                  tipoCampo: json['tipo_campo'] ?? '',
                  obligatorio: (json['obligatorio'] ?? 0) == 1,
                  modulo: moduloAsignado,
                  estadoMostrar: json['estado_mostrar']?.toString(),
                  valor: null, // Sin valor inicial
                );
              }).toList();
          try {
            await prefs.setString(cacheKey, jsonEncode(camposData));
          } catch (_) {}
          return list;
        } else {
          throw Exception(
            result['message'] ?? 'Error obteniendo campos por estado',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [CAMPOS_ADICIONALES] Error obteniendo campos por estado: $e');
      return [];
    }
  }

  /// Obtener campos adicionales con valores para un servicio específico
  static Future<List<CampoAdicionalModel>> obtenerCamposConValores({
    required int servicioId,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print('📡 [CAMPOS_ADICIONALES] Obteniendo campos para servicio $servicioId');
      final isOnline = await ConnectivityService.instance.checkNow();
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'campos_adicionales_valores_$servicioId';
      if (!isOnline) {
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final valoresData = jsonDecode(raw) as List<dynamic>;
            return valoresData.map((json) {
              final moduloJson = (json['modulo'] ?? '').toString().trim();
              final moduloAsignado = moduloJson;
              return CampoAdicionalModel(
                id: json['campo_id'] ?? json['id'] ?? 0,
                nombreCampo: json['nombre_campo'] ?? '',
                tipoCampo: json['tipo_campo'] ?? '',
                obligatorio: (json['obligatorio'] ?? 0) == 1,
                modulo: moduloAsignado,
                estadoMostrar: null,
                valor: json['valor'],
              );
            }).toList();
          } catch (_) {}
        }
        return [];
      }

      final uri = Uri.parse(
        '$_baseUrl/core/fields/obtener_valores_campos_adicionales.php',
      ).replace(
        queryParameters: {
          'servicio_id': servicioId.toString(),
          'modulo': modulo,
        },
      );

      final response = await http.get(uri, headers: _headers);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);

        if (result['success'] == true) {
          final List<dynamic> valoresData = result['valores'] ?? [];

          //           print('✅ [CAMPOS_ADICIONALES] ${valoresData.length} campos con valores obtenidos');

          final list =
              valoresData.map((json) {
                final moduloJson = (json['modulo'] ?? '').toString().trim();
                // Si el backend devuelve módulo vacío:
                // - Asignar 'servicios' SOLO cuando el contexto sea Servicios
                // - En otros contextos (Equipos/otros), conservar vacío
                // No forzar 'servicios' cuando el backend devuelve vacío; mantener tal cual
                final moduloAsignado = moduloJson;
                return CampoAdicionalModel(
                  id: json['campo_id'] ?? 0,
                  nombreCampo: json['nombre_campo'] ?? '',
                  tipoCampo: json['tipo_campo'] ?? '',
                  obligatorio: (json['obligatorio'] ?? 0) == 1,
                  modulo: moduloAsignado,
                  estadoMostrar: null,
                  valor: json['valor'],
                );
              }).toList();
          try {
            await prefs.setString(cacheKey, jsonEncode(valoresData));
          } catch (_) {}
          return list;
        } else {
          throw Exception(
            result['message'] ?? 'Error obteniendo campos adicionales',
          );
        }
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [CAMPOS_ADICIONALES] Error: $e');
      return [];
    }
  }

  /// ✅ NUEVO: Obtener valores específicos de campos para un servicio
  static Future<Map<int, dynamic>> obtenerValoresCamposAdicionales({
    required int servicioId,
    String modulo = 'Servicios',
  }) async {
    try {
      //       print('📡 [CAMPOS_ADICIONALES] Obteniendo valores para servicio $servicioId');

      final campos = await obtenerCamposConValores(
        servicioId: servicioId,
        modulo: modulo,
      );

      final Map<int, dynamic> valores = {};
      for (final campo in campos) {
        if (campo.valor != null) {
          valores[campo.id] = campo.valor;
        }
      }

      //       print('✅ [CAMPOS_ADICIONALES] ${valores.length} valores obtenidos');
      return valores;
    } catch (e) {
      //       print('❌ [CAMPOS_ADICIONALES] Error obteniendo valores: $e');
      return {};
    }
  }

  /// Obtener lista de campos adicionales disponibles (configuración)
  static Future<List<CampoAdicionalModel>> obtenerCamposDisponibles({
    String modulo = 'Servicios',
  }) async {
    try {
      //       print('📡 [CAMPOS_ADICIONALES] Obteniendo campos disponibles para $modulo');

      final isOnline = await ConnectivityService.instance.checkNow();
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = 'campos_disponibles_$modulo';

      // Si no hay conexión, intentar cargar desde cache
      if (!isOnline) {
        final raw = prefs.getString(cacheKey);
        if (raw != null && raw.isNotEmpty) {
          try {
            final camposData = jsonDecode(raw) as List<dynamic>;
            return camposData.map((json) {
              return CampoAdicionalModel(
                id: int.tryParse(json['id'].toString()) ?? 0,
                nombreCampo: json['nombre_campo'] ?? '',
                tipoCampo: json['tipo_campo'] ?? '',
                obligatorio: (json['obligatorio'] ?? 0) == 1,
                modulo: (json['modulo'] ?? '').toString().trim(),
                estadoMostrar: json['estado_mostrar']?.toString(),
                valor: null,
              );
            }).toList();
          } catch (_) {}
        }
        return [];
      }

      final uri = Uri.parse(
        '$_baseUrl/core/fields/listar_campos_adicionales.php',
      );

      final headers = await _getAuthHeaders();
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        final List<dynamic> camposData = jsonDecode(response.body);

        //           print('✅ [CAMPOS_ADICIONALES] ${camposData.length} campos disponibles obtenidos');

        final list = camposData.map((json) {
          return CampoAdicionalModel(
            id: int.tryParse(json['id'].toString()) ?? 0,
            nombreCampo: json['nombre_campo'] ?? '',
            tipoCampo: json['tipo_campo'] ?? '',
            obligatorio: (json['obligatorio'] ?? 0) == 1,
            modulo: (json['modulo'] ?? '').toString().trim(),
            estadoMostrar: json['estado_mostrar']?.toString(),
            valor: null,
          );
        }).toList();

        // Guardar en cache
        try {
          await prefs.setString(cacheKey, jsonEncode(camposData));
        } catch (_) {}

        return list;
      } else {
        throw Exception('Error HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      //       print('❌ [CAMPOS_ADICIONALES] Error obteniendo campos disponibles: $e');
      return [];
    }
  }

  /// Obtener todos los campos adicionales únicos de una lista de servicios
  static Set<CampoAdicionalModel> extraerCamposUnicos(
    List<List<CampoAdicionalModel>> camposPorServicio,
  ) {
    final Set<CampoAdicionalModel> camposUnicos = {};

    for (final campos in camposPorServicio) {
      for (final campo in campos) {
        // Usar el ID y nombre como clave única
        final campoExistente = camposUnicos.firstWhere(
          (c) => c.id == campo.id && c.nombreCampo == campo.nombreCampo,
          orElse:
              () => CampoAdicionalModel(
                id: -1,
                nombreCampo: '',
                tipoCampo: '',
                obligatorio: false,
                modulo: '',
              ),
        );

        if (campoExistente.id == -1) {
          // No existe, agregarlo (sin valor específico)
          camposUnicos.add(
            CampoAdicionalModel(
              id: campo.id,
              nombreCampo: campo.nombreCampo,
              tipoCampo: campo.tipoCampo,
              obligatorio: campo.obligatorio,
              modulo: campo.modulo,
              estadoMostrar: campo.estadoMostrar,
              valor: null, // Sin valor específico para configuración
            ),
          );
        }
      }
    }

    return camposUnicos;
  }

  /// Formatear valor de campo adicional para mostrar en tabla
  static String formatearValorParaTabla(CampoAdicionalModel campo) {
    if (campo.valor == null) return '';

    switch (campo.tipoCampo.toLowerCase()) {
      case 'fecha':
        try {
          final fecha = DateTime.parse(campo.valor.toString());
          return '${fecha.day}/${fecha.month}/${fecha.year}';
        } catch (e) {
          return campo.valor.toString();
        }

      case 'datetime':
      case 'fecha y hora':
        try {
          final fecha = DateTime.parse(campo.valor.toString());
          return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}';
        } catch (e) {
          return campo.valor.toString();
        }

      case 'booleano':
        final boolValue = campo.valor;
        if (boolValue is bool) {
          return boolValue ? 'Sí' : 'No';
        } else if (boolValue is int) {
          return boolValue == 1 ? 'Sí' : 'No';
        } else {
          return campo.valor.toString().toLowerCase() == 'true' ? 'Sí' : 'No';
        }

      case 'moneda':
        try {
          final numero = double.parse(campo.valor.toString());
          return '\$${numero.toStringAsFixed(2)}';
        } catch (e) {
          return campo.valor.toString();
        }

      case 'decimal':
        try {
          final numero = double.parse(campo.valor.toString());
          return numero.toStringAsFixed(2);
        } catch (e) {
          return campo.valor.toString();
        }

      case 'archivo':
      case 'imagen':
        final archivo = campo.valor.toString();
        if (archivo.isNotEmpty) {
          // Mostrar solo el nombre del archivo, no la ruta completa
          final nombreArchivo = archivo.split('/').last;
          return nombreArchivo.length > 20
              ? '${nombreArchivo.substring(0, 17)}...'
              : nombreArchivo;
        }
        return '';

      case 'párrafo':
        final texto = campo.valor.toString();
        // Limitar párrafos largos en la tabla
        return texto.length > 50 ? '${texto.substring(0, 47)}...' : texto;

      default:
        final texto = campo.valor.toString();
        // Limitar texto general en la tabla
        return texto.length > 30 ? '${texto.substring(0, 27)}...' : texto;
    }
  }

  /// Obtener color para tipo de campo adicional
  static Color getColorTipoCampo(String tipoCampo) {
    switch (tipoCampo.toLowerCase()) {
      case 'texto':
      case 'párrafo':
        return Colors.blue.shade600;
      case 'entero':
      case 'decimal':
      case 'moneda':
        return Colors.green.shade600;
      case 'fecha':
      case 'hora':
      case 'datetime':
      case 'fecha y hora':
        return Colors.orange.shade600;
      case 'booleano':
        return Colors.purple.shade600;
      case 'archivo':
      case 'imagen':
        return Colors.indigo.shade600;
      case 'link':
        return Colors.cyan.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  /// Obtener ícono para tipo de campo adicional
  static IconData getIconoTipoCampo(String tipoCampo) {
    switch (tipoCampo.toLowerCase()) {
      case 'texto':
        return PhosphorIcons.textT();
      case 'párrafo':
        return PhosphorIcons.note();
      case 'entero':
      case 'decimal':
        return PhosphorIcons.hash();
      case 'moneda':
        return PhosphorIcons.currencyDollar();
      case 'fecha':
        return PhosphorIcons.calendar();
      case 'hora':
        return PhosphorIcons.clock();
      case 'datetime':
      case 'fecha y hora':
        return PhosphorIcons.clock();
      case 'booleano':
        return PhosphorIcons.checkSquare();
      case 'archivo':
        return PhosphorIcons.paperclip();
      case 'imagen':
        return PhosphorIcons.image();
      case 'link':
        return PhosphorIcons.link();
      default:
        return PhosphorIcons.puzzlePiece();
    }
  }

  /// ✅ NUEVO: Validar campos obligatorios de una lista de campos
  static List<String> validarCamposObligatorios(
    List<CampoAdicionalModel> campos,
    Map<int, dynamic> valores,
  ) {
    final camposObligatoriosIncompletos = <String>[];

    for (final campo in campos) {
      if (campo.obligatorio) {
        final valor = valores[campo.id];

        if (_esValorVacio(valor, campo.tipoCampo)) {
          camposObligatoriosIncompletos.add(campo.nombreCampo);
        }
      }
    }

    return camposObligatoriosIncompletos;
  }

  /// Método auxiliar para validar si un valor está vacío
  static bool _esValorVacio(dynamic valor, String tipoCampo) {
    if (valor == null) return true;

    switch (tipoCampo.toLowerCase()) {
      case 'texto':
      case 'párrafo':
      case 'link':
        return valor.toString().trim().isEmpty;

      case 'entero':
      case 'decimal':
      case 'moneda':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'fecha':
      case 'hora':
      case 'datetime':
      case 'fecha y hora':
        return valor == null || (valor is String && valor.trim().isEmpty);

      case 'imagen':
      case 'archivo':
        if (valor is Map<String, dynamic>) {
          return valor.isEmpty ||
              valor['nombre'] == null ||
              valor['nombre'].toString().trim().isEmpty;
        }
        return valor.toString().trim().isEmpty;

      case 'booleano':
        return false; // Los campos booleanos nunca están "vacíos"

      default:
        return valor.toString().trim().isEmpty;
    }
  }
  // Helper para headers con autenticación
  static Future<Map<String, String>> _getAuthHeaders() async {
    final token = await AuthService.getBearerToken();
    return {
      ..._headers,
      if (token != null) 'Authorization': token,
    };
  }
}
