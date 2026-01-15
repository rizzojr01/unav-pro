import '../../domain/entities/localization_request_entity.dart';

class LocalizationRequestModel extends LocalizationRequestEntity {
  const LocalizationRequestModel({
    required super.base64Image,
    required super.building,
    required super.floor,
    required super.place,
    required super.sessionId,
    super.unavMultifloor,
    super.useSampleImage,
  });

  Map<String, dynamic> toJson() {
    return {
      'base_64_image': base64Image,
      'building': building,
      'floor': floor,
      'place': place,
      'session_id': sessionId,
      'unav_multifloor': unavMultifloor,
      'use_sample_image': useSampleImage,
    };
  }

  factory LocalizationRequestModel.fromEntity(
    LocalizationRequestEntity entity,
  ) {
    return LocalizationRequestModel(
      base64Image: entity.base64Image,
      building: entity.building,
      floor: entity.floor,
      place: entity.place,
      sessionId: entity.sessionId,
      unavMultifloor: entity.unavMultifloor,
      useSampleImage: entity.useSampleImage,
    );
  }
}
