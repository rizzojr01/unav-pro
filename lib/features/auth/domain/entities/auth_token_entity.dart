import 'package:smart_sense/core/base/base_entity.dart';
import 'package:smart_sense/features/profile/domain/entities/user_entity.dart';

class AuthTokenEntity extends BaseEntity {
  final String accessToken;
  final String tokenType;
  final UserEntity user;

  const AuthTokenEntity({
    required this.accessToken,
    required this.tokenType,
    required this.user,
  });

  @override
  String get id => accessToken;

  @override
  List<Object?> get props => [accessToken, tokenType, user];
}
