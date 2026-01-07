import 'dart:convert';
import 'package:smart_sense/core/constants/app_constants.dart';
import 'package:smart_sense/core/services/storage_service.dart';
import 'package:smart_sense/features/profile/data/models/user_model.dart';

abstract class AuthLocalDataSource {
  Future<void> saveToken(String token);
  String? getToken();
  Future<void> saveUser(UserModel user);
  UserModel? getUser();
  Future<void> clearAll();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final StorageService storageService;

  AuthLocalDataSourceImpl(this.storageService);

  @override
  Future<void> saveToken(String token) async {
    await storageService.setString(AppConstants.tokenKey, token);
  }

  @override
  String? getToken() {
    return storageService.getString(AppConstants.tokenKey);
  }

  @override
  Future<void> saveUser(UserModel user) async {
    final userJson = jsonEncode(user.toJson());
    await storageService.setString(AppConstants.userKey, userJson);
  }

  @override
  UserModel? getUser() {
    final userJson = storageService.getString(AppConstants.userKey);
    if (userJson != null) {
      return UserModel.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
    }
    return null;
  }

  @override
  Future<void> clearAll() async {
    await storageService.remove(AppConstants.tokenKey);
    await storageService.remove(AppConstants.userKey);
  }
}
