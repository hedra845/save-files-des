class ImageModel {
  final int? id;
  final String name;
  final String path;
  final int? size;
  final int? categoryId;
  final String createdAt;

  ImageModel({
    this.id,
    required this.name,
    required this.path,
    this.size,
    this.categoryId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'size': size,
      'category_id': categoryId,
      'created_at': createdAt,
    };
  }

  factory ImageModel.fromMap(Map<String, dynamic> map) {
    return ImageModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      path: map['path'] as String,
      size: map['size'] as int?,
      categoryId: map['category_id'] as int?,
      createdAt: map['created_at'] as String,
    );
  }
}
