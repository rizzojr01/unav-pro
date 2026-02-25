import '../../../../core/base/base_entity.dart';

class LocationEntity extends BaseEntity {
  final double x;
  final double y;
  final double? ang;
  final String? floor;
  final DateTime? timestamp;

  const LocationEntity({
    required this.x,
    required this.y,
    this.ang,
    this.floor,
    this.timestamp,
  });

  @override
  String? get id => '${x}_${y}_${timestamp?.millisecondsSinceEpoch ?? 0}';

  LocationEntity copyWith({
    double? x,
    double? y,
    double? ang,
    String? floor,
    DateTime? timestamp,
  }) {
    return LocationEntity(
      x: x ?? this.x,
      y: y ?? this.y,
      ang: ang ?? this.ang,
      floor: floor ?? this.floor,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [x, y, ang, floor, timestamp];
}
