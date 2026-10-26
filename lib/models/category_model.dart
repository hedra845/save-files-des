class CategoryModel {
  final int? id;
  final String name;
  final String type;
  final String? color;
  final String createdAt;

  CategoryModel({
    this.id,
    required this.name,
    required this.type,
    this.color,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'color': color,
      'created_at': createdAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      type: map['type'] as String,
      color: map['color'] as String?,
      createdAt: map['created_at'] as String,
    );
  }
}

