class Tag {
  final String tag;
  final String field;
  final String description;
  final String type;
  final int? campoId;
  final String? nombreOriginal;

  Tag({
    required this.tag,
    required this.field,
    required this.description,
    required this.type,
    this.campoId,
    this.nombreOriginal,
  });

  factory Tag.fromJson(Map<String, dynamic> json) {
    return Tag(
      tag: json['tag'] ?? '',
      field: json['field'] ?? '',
      description: json['description'] ?? '',
      type: json['type'] ?? '',
      campoId: json['campo_id'],
      nombreOriginal: json['nombre_original'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'tag': tag,
      'field': field,
      'description': description,
      'type': type,
      if (campoId != null) 'campo_id': campoId,
      if (nombreOriginal != null) 'nombre_original': nombreOriginal,
    };
  }
}
