/// Clase base para mapear entidades a tags de plantilla HTML.
abstract class BaseTagMapper<T> {
  const BaseTagMapper();

  /// Mapea la entidad [entity] a un mapa de etiquetas/valores.
  Map<String, String> mapTags(T entity);

  /// Helper para formatear un tag con su valor.
  /// Ej: 'equipo_nombre' -> 'Excavadora'
  MapEntry<String, String> entry(String key, dynamic value) {
    return MapEntry(key, value?.toString() ?? '');
  }

  /// Limpia y estandariza las llaves de los tags.
  /// Soporta {{tag}} y [tag]
  String processTemplate(String html, T entity) {
    final tags = mapTags(entity);
    String processed = html;

    tags.forEach((key, value) {
      // Reemplazar {{tag}}
      processed = processed.replaceAll('{{$key}}', value);
      // Reemplazar [tag]
      processed = processed.replaceAll('[$key]', value);
    });

    return processed;
  }
}
