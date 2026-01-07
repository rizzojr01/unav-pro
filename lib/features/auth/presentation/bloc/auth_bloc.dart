import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:smart_sense/core/base/usecase.dart';
import 'package:smart_sense/features/profile/domain/usecases/get_me_usecase.dart';
import 'package:smart_sense/features/auth/domain/usecases/login_usecase.dart';
import 'package:smart_sense/features/auth/domain/usecases/logout_usecase.dart';
import 'package:smart_sense/features/auth/domain/usecases/signup_usecase.dart';
import 'auth_event.dart';
import 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final LoginUseCase loginUseCase;
  final SignupUseCase signupUseCase;
  final GetMeUseCase getMeUseCase;
  final LogoutUseCase logoutUseCase;

  AuthBloc({
    required this.loginUseCase,
    required this.signupUseCase,
    required this.getMeUseCase,
    required this.logoutUseCase,
  }) : super(AuthInitial()) {
    on<LoginSubmitted>(_onLoginSubmitted);
    on<SignupSubmitted>(_onSignupSubmitted);
    on<AuthLogoutRequested>(_onLogoutRequested);
    on<AuthCheckRequested>(_onAuthCheckRequested);
  }

  Future<void> _onLoginSubmitted(
    LoginSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await loginUseCase(
      LoginParams(email: event.email, password: event.password),
    );
    result.fold(
      (failure) => emit(AuthFailure(message: failure.message)),
      (authToken) => emit(Authenticated(user: authToken.user)),
    );
  }

  Future<void> _onSignupSubmitted(
    SignupSubmitted event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await signupUseCase(
      SignupParams(
        email: event.email,
        nickname: event.nickname,
        password: event.password,
      ),
    );
    result.fold(
      (failure) => emit(AuthFailure(message: failure.message)),
      (authToken) => emit(Authenticated(user: authToken.user)),
    );
  }

  Future<void> _onLogoutRequested(
    AuthLogoutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await logoutUseCase(NoParams());
    result.fold(
      (failure) => emit(AuthFailure(message: failure.message)),
      (_) => emit(Unauthenticated()),
    );
  }

  Future<void> _onAuthCheckRequested(
    AuthCheckRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());
    final result = await getMeUseCase(NoParams());
    result.fold(
      (failure) => emit(Unauthenticated()),
      (user) => emit(Authenticated(user: user)),
    );
  }
}
