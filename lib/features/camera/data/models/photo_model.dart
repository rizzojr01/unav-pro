import '../../domain/entities/photo_entity.dart';

class PhotoModel extends PhotoEntity {
  const PhotoModel({
    required super.id,
    required super.filePath,
    required super.timestamp,
  });

  factory PhotoModel.fromJson(Map<String, dynamic> json) {
    return PhotoModel(
      id: json['id'] as String,
      filePath: json['filePath'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filePath': filePath,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory PhotoModel.fromEntity(PhotoEntity entity) {
    return PhotoModel(
      id: entity.id,
      filePath: entity.filePath,
      timestamp: entity.timestamp,
    );
  }
}
