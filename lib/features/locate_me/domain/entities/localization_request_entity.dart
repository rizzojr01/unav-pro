import '../../../../core/base/base_entity.dart';

/// Entity representing a localization request to the backend
class LocalizationRequestEntity extends BaseEntity {
  final String base64Image;
  final String building;
  final String floor;
  final String place;
  final String sessionId;
  final bool unavMultifloor;
  final bool useSampleImage;

  const LocalizationRequestEntity({
    required this.base64Image,
    required this.building,
    required this.floor,
    required this.place,
    required this.sessionId,
    this.unavMultifloor = false,
    this.useSampleImage = false,
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
  ];
}
