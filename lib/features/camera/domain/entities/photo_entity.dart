import '../../../../core/base/base_entity.dart';

class PhotoEntity extends BaseEntity {
  final String id;
  final String filePath;
  final DateTime timestamp;

  const PhotoEntity({
    required this.id,
    required this.filePath,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [id, filePath, timestamp];
}
