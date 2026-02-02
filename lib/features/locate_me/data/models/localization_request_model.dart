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
    super.relocalize,
    super.saveframe,
    super.shortenVlmResponse,
    super.speakVlmFirst,
    super.useVlm,
    super.imageCompression,
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
      'relocalize': relocalize,
      'saveframe': saveframe,
      'shorten_vlm_response': shortenVlmResponse,
      'speakVlmFirst': speakVlmFirst,
      'use_vlm': useVlm,
      if (imageCompression != null)
        'image_compression': {
          'enable_compression': imageCompression!.enableCompression,
          'max_height': imageCompression!.maxHeight,
          'max_width': imageCompression!.maxWidth,
          'quality': imageCompression!.quality,
        },
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
      relocalize: entity.relocalize,
      saveframe: entity.saveframe,
      shortenVlmResponse: entity.shortenVlmResponse,
      speakVlmFirst: entity.speakVlmFirst,
      useVlm: entity.useVlm,
      imageCompression: entity.imageCompression,
    );
  }
}
