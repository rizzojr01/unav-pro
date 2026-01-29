import '../../domain/entities/localization_history_entity.dart';

class LocalizationHistoryModel extends LocalizationHistoryEntity {
  const LocalizationHistoryModel({
    required super.historyId,
    required super.userIdentifier,
    required super.identifierType,
    required super.sessionId,
    required super.destinationId,
    required super.building,
    required super.floor,
    required super.place,
    super.userPovImageId,
    super.unavOutput,
    required super.createdAt,
  });

  factory LocalizationHistoryModel.fromJson(Map<String, dynamic> json) {
    return LocalizationHistoryModel(
      historyId: json['id'] as int,
      userIdentifier: json['user_identifier'] as String,
      identifierType: json['identifier_type'] as String,
      sessionId: json['session_id'] as String,
      destinationId: json['destination_id'] as String,
      building: json['building'] as String,
      floor: json['floor'] as String,
      place: json['place'] as String,
      userPovImageId: json['user_pov_image_id'] as String?,
      unavOutput: json['unav_output'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': historyId,
      'user_identifier': userIdentifier,
      'identifier_type': identifierType,
      'session_id': sessionId,
      'destination_id': destinationId,
      'building': building,
      'floor': floor,
      'place': place,
      'user_pov_image_id': userPovImageId,
      'unav_output': unavOutput,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory LocalizationHistoryModel.fromEntity(LocalizationHistoryEntity entity) {
    return LocalizationHistoryModel(
      historyId: entity.historyId,
      userIdentifier: entity.userIdentifier,
      identifierType: entity.identifierType,
      sessionId: entity.sessionId,
      destinationId: entity.destinationId,
      building: entity.building,
      floor: entity.floor,
      place: entity.place,
      userPovImageId: entity.userPovImageId,
      unavOutput: entity.unavOutput,
      createdAt: entity.createdAt,
    );
  }

  static List<LocalizationHistoryModel> fromJsonList(List<dynamic> jsonList) {
    return jsonList
        .map((e) => LocalizationHistoryModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
