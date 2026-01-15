import '../../domain/entities/floor_plan_entity.dart';

class FloorPlanModel extends FloorPlanEntity {
  const FloorPlanModel({required super.base64Image, required super.filename});

  factory FloorPlanModel.fromJson(Map<String, dynamic> json) {
    return FloorPlanModel(
      base64Image: json['base64'] as String,
      filename: json['filename'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'base64': base64Image, 'filename': filename};
  }

  factory FloorPlanModel.fromEntity(FloorPlanEntity entity) {
    return FloorPlanModel(
      base64Image: entity.base64Image,
      filename: entity.filename,
    );
  }
}
