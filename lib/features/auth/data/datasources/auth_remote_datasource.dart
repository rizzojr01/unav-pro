import 'package:smart_sense/core/network/api_client.dart';
import 'package:smart_sense/core/constants/api_routes.dart';
import '../models/auth_response_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  });

  Future<AuthResponseModel> signup({
    required String email,
    required String nickname,
    required String password,
  });
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final ApiClient apiClient;

  AuthRemoteDataSourceImpl(this.apiClient);

  @override
  Future<AuthResponseModel> login({
    required String email,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiRoutes.login,
      data: {'email': email, 'password': password},
    );
    return AuthResponseModel.fromJson(response as Map<String, dynamic>);
  }

  @override
  Future<AuthResponseModel> signup({
    required String email,
    required String nickname,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiRoutes.signup,
      data: {'email': email, 'nickname': nickname, 'password': password},
    );
    return AuthResponseModel.fromJson(response as Map<String, dynamic>);
  }
}
