class FileModel {
  final int? id;
  final String name;
  final String path;
  final String type;
  final int? size;
  final int? categoryId;
  final String createdAt;

  FileModel({
    this.id,
    required this.name,
    required this.path,
    required this.type,
    this.size,
    this.categoryId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'path': path,
      'type': type,
      'size': size,
      'category_id': categoryId,
      'created_at': createdAt,
    };
  }

  factory FileModel.fromMap(Map<String, dynamic> map) {
    return FileModel(
      id: map['id'] as int?,
      name: map['name'] as String,
      path: map['path'] as String,
      type: map['type'] as String,
      size: map['size'] as int?,
      categoryId: map['category_id'] as int?,
      createdAt: map['created_at'] as String,
    );
  }
}
