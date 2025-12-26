import '../../../../core/base/base_entity.dart';

class LocationEntity extends BaseEntity {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  const LocationEntity({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  @override
  String? get id =>
      '${latitude}_${longitude}_${timestamp.millisecondsSinceEpoch}';

  @override
  List<Object?> get props => [latitude, longitude, timestamp];
}
