import '../../../../core/base/base_entity.dart';

/// Entity representing a floor plan image
class FloorPlanEntity extends BaseEntity {
  final String base64Image;
  final String filename;

  const FloorPlanEntity({required this.base64Image, required this.filename});

  @override
  String? get id => filename;

  @override
  List<Object?> get props => [base64Image, filename];
}
