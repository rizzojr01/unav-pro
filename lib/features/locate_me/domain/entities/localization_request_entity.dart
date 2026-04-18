import '../../../../core/base/base_entity.dart';

class ImageCompressionEntity extends BaseEntity {
  final bool enableCompression;
  final int maxHeight;
  final int maxWidth;
  final int quality;

  const ImageCompressionEntity({
    required this.enableCompression,
    required this.maxHeight,
    required this.maxWidth,
    required this.quality,
  });

  @override
  String? get id => null;

  @override
  List<Object?> get props => [enableCompression, maxHeight, maxWidth, quality];
}

/// Entity representing a localization request to the backend
class LocalizationRequestEntity extends BaseEntity {
  final String base64Image;
  final String building;
  final String floor;
  final String place;
  final String sessionId;
  final bool unavMultifloor;
  final bool useSampleImage;
  final bool relocalize;
  final bool saveframe;
  final bool shortenVlmResponse;
  final bool speakVlmFirst;
  final bool useVlm;
  final double offsetInMeters;
  final ImageCompressionEntity? imageCompression;

  const LocalizationRequestEntity({
    required this.base64Image,
    required this.building,
    required this.floor,
    required this.place,
    required this.sessionId,
    this.unavMultifloor = false,
    this.useSampleImage = false,
    this.relocalize = true,
    this.saveframe = false,
    this.shortenVlmResponse = true,
    this.speakVlmFirst = true,
    this.useVlm = false,
    this.offsetInMeters = 0.0,
    this.imageCompression,
  });

  @override
  String? get id => sessionId;

  @override
  List<Object?> get props => [
    base64Image,
    building,
    floor,
    place,
    sessionId,
    unavMultifloor,
    useSampleImage,
    relocalize,
    saveframe,
    shortenVlmResponse,
    speakVlmFirst,
    useVlm,
    offsetInMeters,
    imageCompression,
  ];
}
