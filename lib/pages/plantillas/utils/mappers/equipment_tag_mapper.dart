import '../../../servicios/models/equipo_model.dart';
import 'base_tag_mapper.dart';

class EquipmentTagMapper extends BaseTagMapper<EquipoModel> {
  const EquipmentTagMapper();

  @override
  Map<String, String> mapTags(EquipoModel equipo) {
    return {
      'equipo_nombre': equipo.nombre,
      'equipo_marca': equipo.marca ?? '',
      'equipo_modelo': equipo.modelo ?? '',
      'equipo_placa': equipo.placa ?? '',
      'equipo_codigo': equipo.codigo ?? '',
      'nombre_empresa': equipo.nombreEmpresa ?? '',
    };
  }
}
