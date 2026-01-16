import '../../domain/entities/user_position_entity.dart';

/// Exception thrown when localization fails with an internal error status
class LocalizationFailedException implements Exception {
  final String message;
  final String? errorCode;

  LocalizationFailedException(this.message, {this.errorCode});

  @override
  String toString() => message;
}

class UserPositionModel extends UserPositionEntity {
  const UserPositionModel({
    required super.x,
    required super.y,
    required super.angle,
  });

  factory UserPositionModel.fromJson(Map<String, dynamic> json) {
    final result = json['result'] as Map<String, dynamic>?;
    if (result != null) {
      // Check for internal error status in result
      final internalStatus = result['status'] as String?;
      if (internalStatus == 'error') {
        final errorMessage =
            result['error'] as String? ?? 'Localization failed';
        final errorCode = result['error_code'] as String?;
        throw LocalizationFailedException(errorMessage, errorCode: errorCode);
      }

      return UserPositionModel(
        x: (result['x'] as num).toDouble(),
        y: (result['y'] as num).toDouble(),
        angle: (result['ang'] as num).toDouble(),
      );
    }
    return UserPositionModel(
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      angle: (json['ang'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y, 'ang': angle};
  }

  factory UserPositionModel.fromEntity(UserPositionEntity entity) {
    return UserPositionModel(x: entity.x, y: entity.y, angle: entity.angle);
  }
}
