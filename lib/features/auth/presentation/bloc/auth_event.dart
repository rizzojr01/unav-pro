import 'package:smart_sense/core/base/base_event.dart';

abstract class AuthEvent extends BaseEvent {}

class LoginSubmitted extends AuthEvent {
  final String email;
  final String password;

  LoginSubmitted({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class SignupSubmitted extends AuthEvent {
  final String email;
  final String nickname;
  final String password;

  SignupSubmitted({
    required this.email,
    required this.nickname,
    required this.password,
  });

  @override
  List<Object?> get props => [email, nickname, password];
}

class AuthLogoutRequested extends AuthEvent {
  @override
  List<Object?> get props => [];
}

class AuthCheckRequested extends AuthEvent {
  @override
  List<Object?> get props => [];
}
