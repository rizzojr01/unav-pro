import '../../../../core/base/base_entity.dart';

class PhotoEntity extends BaseEntity {
  final String entityId;
  final String filePath;
  final DateTime timestamp;

  const PhotoEntity({
    required this.entityId,
    required this.filePath,
    required this.timestamp,
  });

  @override
  String? get id => entityId;

  @override
  List<Object?> get props => [entityId, filePath, timestamp];
}
