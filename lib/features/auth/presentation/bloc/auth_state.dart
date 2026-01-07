import 'package:smart_sense/core/base/base_state.dart';
import 'package:smart_sense/features/profile/domain/entities/user_entity.dart';

abstract class AuthState extends BaseState {}

class AuthInitial extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthLoading extends AuthState {
  @override
  List<Object?> get props => [];
}

class Authenticated extends AuthState {
  final UserEntity user;

  Authenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class Unauthenticated extends AuthState {
  @override
  List<Object?> get props => [];
}

class AuthFailure extends AuthState {
  final String message;

  AuthFailure({required this.message});

  @override
  List<Object?> get props => [message];
}
