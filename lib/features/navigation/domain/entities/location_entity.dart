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

  @override
  List<Object?> get props => [x, y, ang, floor, timestamp];
}
