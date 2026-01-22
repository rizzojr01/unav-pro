import '../../../../core/base/base_entity.dart';

class LocationEntity extends BaseEntity {
  final double x;
  final double y;
  final double? ang;
  final DateTime? timestamp;

  const LocationEntity({
    required this.x,
    required this.y,
    this.ang,
    this.timestamp,
  });

  @override
  String? get id => '${x}_${y}_${timestamp?.millisecondsSinceEpoch ?? 0}';

  @override
  List<Object?> get props => [x, y, ang, timestamp];
}
