import '../../../clientes/models/cliente_model.dart';
import 'base_tag_mapper.dart';

class ClientTagMapper extends BaseTagMapper<ClienteModel> {
  const ClientTagMapper();

  @override
  Map<String, String> mapTags(ClienteModel cliente) {
    return {
      'cliente_nombre': cliente.nombreCompleto ?? '',
      'cliente_nit': cliente.documentoNit ?? '',
      'cliente_documento': cliente.documentoNit ?? '',
      'cliente_direccion': cliente.direccion ?? '',
      'cliente_email': cliente.email ?? '',
      'cliente_telefono': cliente.telefonoPrincipal ?? '',
      'cliente_ciudad': cliente.ciudadNombre ?? '',
    };
  }
}
