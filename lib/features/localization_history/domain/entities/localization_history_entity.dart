import '../../../../core/base/base_entity.dart';

class LocalizationHistoryEntity extends BaseEntity {
  final int historyId;
  final String userIdentifier;
  final String identifierType; // 'email' or 'device'
  final String sessionId;
  final String destinationId;
  final String? destinationName;
  final String building;
  final String floor;
  final String place;
  final String? userPovImageId;
  final String? unavOutput;
  final DateTime createdAt;

  const LocalizationHistoryEntity({
    required this.historyId,
    required this.userIdentifier,
    required this.identifierType,
    required this.sessionId,
    required this.destinationId,
    this.destinationName,
    required this.building,
    required this.floor,
    required this.place,
    this.userPovImageId,
    this.unavOutput,
    required this.createdAt,
  });

  @override
  String? get id => historyId.toString();

  @override
  List<Object?> get props => [
    historyId,
    userIdentifier,
    identifierType,
    sessionId,
    destinationId,
    building,
    floor,
    place,
    userPovImageId,
    unavOutput,
    createdAt,
  ];
}
