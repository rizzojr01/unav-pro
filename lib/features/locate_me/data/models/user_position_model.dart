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
    // Check top-level status first
    final status = json['status'] as String?;
    if (status == 'error' || status == 'fail') {
      final errorMessage =
          json['error'] as String? ??
          json['message'] as String? ??
          'Localization failed';
      throw LocalizationFailedException(errorMessage);
    }

    // The response has result.result structure
    final outerResult = json['result'] as Map<String, dynamic>?;
    if (outerResult != null) {
      // Check if there's a nested result (result.result)
      final innerResult = outerResult['result'] as Map<String, dynamic>?;

      if (innerResult != null) {
        // Parse from nested result.result
        return UserPositionModel(
          x: (innerResult['x'] as num).toDouble(),
          y: (innerResult['y'] as num).toDouble(),
          angle: (innerResult['ang'] as num).toDouble(),
        );
      }

      // Check for internal error status in result
      final internalStatus = outerResult['status'] as String?;
      if (internalStatus == 'error') {
        final errorMessage =
            outerResult['error'] as String? ?? 'Localization failed';
        final errorCode = outerResult['error_code'] as String?;
        throw LocalizationFailedException(errorMessage, errorCode: errorCode);
      }

      // Parse from direct result (fallback for different API response format)
      if (outerResult.containsKey('x')) {
        return UserPositionModel(
          x: (outerResult['x'] as num).toDouble(),
          y: (outerResult['y'] as num).toDouble(),
          angle: (outerResult['ang'] as num).toDouble(),
        );
      }
    }

    // Fallback: parse from root level
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
