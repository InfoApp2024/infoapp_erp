import '../../../servicios/models/servicio_model.dart';
import '../../../servicios/models/equipo_model.dart';
import '../../../clientes/models/cliente_model.dart';
import '../../../inspecciones/models/inspeccion_model.dart';
import '../../models/tag_category_model.dart';
import 'service_tag_mapper.dart';
import 'equipment_tag_mapper.dart';
import 'client_tag_mapper.dart';
import 'inspection_tag_mapper.dart';

class TagEngine {
  static const _serviceMapper = ServiceTagMapper();
  static const _equipmentMapper = EquipmentTagMapper();
  static const _clientMapper = ClientTagMapper();
  static const _inspectionMapper = InspectionTagMapper();

  /// Procesa un HTML reemplazando tags usando modelos disponibles según el contexto.
  static String processAll(
    String html, {
    String modulo = 'servicios',
    dynamic model, // El modelo principal (ServicioModel, InspeccionModel, etc)
    EquipoModel? equipment,
    ClienteModel? client,
    Map<int, dynamic>? customFields,
    List<TagCategory>? availableTags,
  }) {
    String result = html;

    // 1. Procesar tags del módulo principal
    if (model != null) {
      if (modulo == 'servicios' && model is ServicioModel) {
        result = _serviceMapper.processTemplate(result, model);
      } else if (modulo == 'inspecciones' && model is InspeccionModel) {
        result = _inspectionMapper.processTemplate(result, model);
      }
      // Se pueden añadir más módulos aquí
    }

    // 2. Procesar tags comunes
    if (equipment != null) {
      result = _equipmentMapper.processTemplate(result, equipment);
    }
    if (client != null) {
      result = _clientMapper.processTemplate(result, client);
    }

    // 3. Procesar campos adicionales dinámicos
    if (customFields != null && availableTags != null) {
      for (var category in availableTags) {
        for (var tag in category.tags) {
          if (tag.campoId != null && customFields.containsKey(tag.campoId)) {
            final value = customFields[tag.campoId]?.toString() ?? '';
            result = result.replaceAll('{{${tag.tag}}}', value);
            result = result.replaceAll('[${tag.tag}]', value);
          }
        }
      }
    }

    return result;
  }

  /// Valida los tags en un HTML comparándolos con los tags disponibles.
  static Map<String, dynamic> validateTagsLocally(
    String html,
    List<TagCategory> availableTags, {
    String modulo = 'servicios',
  }) {
    final regExp = RegExp(r'\{\{\s*(.+?)\s*\}\}|\[\s*(.+?)\s*\]');
    final matches = regExp.allMatches(html);
    
    final Set<String> foundTags = {};
    for (var match in matches) {
      final tag = (match.group(1) ?? match.group(2) ?? '').trim();
      if (tag.isNotEmpty) foundTags.add(tag);
    }

    final Set<String> knownTags = {
      'branding_logo_url',
      'branding_color_primario',
      'repuestos_filas',
      'tabla_fotos',
      'tabla_fotos_comparativa',
      'firma_cliente',
      'firma_tecnico',
    };

    // Agregar tags comunes
    knownTags.addAll(_equipmentMapper.mapTags(const EquipoModel(id: 0, nombre: '')).keys);
    knownTags.addAll(_clientMapper.mapTags(ClienteModel()).keys);

    // Agregar tags según módulo
    if (modulo == 'servicios') {
      knownTags.addAll(_serviceMapper.mapTags(ServicioModel()).keys);
    } else if (modulo == 'inspecciones') {
      knownTags.addAll(_inspectionMapper.mapTags(const InspeccionModel()).keys);
    }

    // Agregar tags de categorías disponibles (traídos del backend para este módulo)
    for (var category in availableTags) {
      for (var tag in category.tags) {
        knownTags.add(tag.tag);
      }
    }

    final List<String> validos = [];
    final List<String> invalidos = [];

    for (var tag in foundTags) {
      if (knownTags.contains(tag)) {
        validos.add(tag);
      } else {
        invalidos.add(tag);
      }
    }

    return {
      'es_valido': invalidos.isEmpty,
      'tags_validos': validos,
      'tags_invalidos': invalidos,
      'total_encontrados': foundTags.length,
    };
  }
}
