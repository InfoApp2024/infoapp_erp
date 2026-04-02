import '../../../inspecciones/models/inspeccion_model.dart';
import 'base_tag_mapper.dart';

class InspectionTagMapper extends BaseTagMapper<InspeccionModel> {
  const InspectionTagMapper();

  @override
  Map<String, String> mapTags(InspeccionModel inspeccion) {
    return {
      'inspeccion_id': inspeccion.id?.toString() ?? '',
      'inspeccion_codigo': inspeccion.oInspe ?? '',
      'o_inspeccion': inspeccion.oInspe ?? '',
      'fecha_inspeccion': inspeccion.fechaInspe ?? '',
      'sitio': inspeccion.sitio ?? '',
      'estado_inspeccion': inspeccion.estadoNombre ?? '',
      'inspector_nombre': inspeccion.creadoPorNombre ?? '',
      'equipo_inspeccionado': inspeccion.equipoNombre ?? '',
      'placa_equipo': inspeccion.equipoPlaca ?? '',
      'total_sistemas': inspeccion.totalSistemas?.toString() ?? '0',
      'total_actividades': inspeccion.totalActividades?.toString() ?? '0',
      'actividades_autorizadas': inspeccion.actividadesAutorizadas?.toString() ?? '0',
    };
  }
}
