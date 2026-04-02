import 'tag_model.dart';

class TagCategory {
  final String name;
  final String description;
  final List<Tag> tags;

  TagCategory({
    required this.name,
    required this.description,
    required this.tags,
  });

  factory TagCategory.fromJson(Map<String, dynamic> json) {
    return TagCategory(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      tags: (json['tags'] as List?)
              ?.map((tag) => Tag.fromJson(tag))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'tags': tags.map((Tag tag) => tag.toJson()).toList(),
    };
  }

  TagCategory copyWith({
    String? name,
    String? description,
    List<Tag>? tags,
  }) {
    return TagCategory(
      name: name ?? this.name,
      description: description ?? this.description,
      tags: tags ?? this.tags,
    );
  }
}
