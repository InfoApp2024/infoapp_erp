import '../../../servicios/models/servicio_model.dart';
import 'base_tag_mapper.dart';

class ServiceTagMapper extends BaseTagMapper<ServicioModel> {
  const ServiceTagMapper();

  @override
  Map<String, String> mapTags(ServicioModel service) {
    return {
      'servicio_codigo': service.oServicio?.toString() ?? '',
      'o_servicio': service.oServicio?.toString() ?? '',
      'servicio_id': service.id?.toString() ?? '',
      'fecha_ingreso': service.fechaIngreso ?? '',
      'orden_cliente': service.ordenCliente ?? '',
      'tipo_mantenimiento': service.tipoMantenimiento ?? '',
      'tipo_servicio': service.tipoMantenimiento ?? '',
      'centro_costo': service.centroCosto ?? '',
      'estado': service.estadoNombre ?? '',
      'estado_servicio': service.estadoNombre ?? '',
      'razon_anulacion': service.razon ?? '',
      'actividad': service.actividadNombre ?? '',
      'actividad_cant_hora': service.cantHora?.toString() ?? '0',
      'actividad_num_tecnicos': service.numTecnicos?.toString() ?? '1',
      'actividad_tiempo_total': service.tiempoTotal.toString(),
      'sistema_nombre': service.sistemaNombre ?? '',
      'tecnico_asignado': service.funcionarioNombre ?? '',
    };
  }
}
