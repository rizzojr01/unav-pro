import 'package:smart_sense/core/base/base_entity.dart';

class UserEntity extends BaseEntity {
  @override
  final String id;
  final String email;
  final String nickname;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserEntity({
    required this.id,
    required this.email,
    required this.nickname,
    required this.createdAt,
    required this.updatedAt,
  });

  @override
  List<Object?> get props => [id, email, nickname, createdAt, updatedAt];
}
