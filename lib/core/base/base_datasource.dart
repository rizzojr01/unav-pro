import 'dart:io';

import 'package:dio/dio.dart';
import 'package:smart_sense/core/error/exceptions.dart';
import 'package:smart_sense/core/network/api_client.dart';

/// Base class for all remote data sources
/// Handles common API operations and exception management
abstract class BaseRemoteDataSource {
  final ApiClient apiClient;

  BaseRemoteDataSource(this.apiClient);

  /// Execute API call with error handling
  Future<T> executeCall<T>(
    Future<T> Function() call, {
    String errorMessage = 'An error occurred',
  }) async {
    try {
      return await call();
    } on ServerException {
      rethrow;
    } on NetworkException {
      rethrow;
    } on DioException catch (e) {
      throw _handleDioException(e, errorMessage);
    } on SocketException catch (e) {
      throw NetworkException(e.message);
    } catch (e) {
      throw ServerException(errorMessage, 500);
    }
  }

  /// GET request helper
  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return executeCall(() async {
      final response = await apiClient.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );
      return response;
    }, errorMessage: 'GET request failed for $path');
  }

  /// POST request helper
  Future<Map<String, dynamic>> post(String path, {Object? data}) async {
    return executeCall(() async {
      final response = await apiClient.post<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response;
    }, errorMessage: 'POST request failed for $path');
  }

  /// POST multipart request helper (using FormData)
  Future<Map<String, dynamic>> postMultipart(
    String path, {
    required FormData formData,
  }) async {
    return executeCall(() async {
      final response = await apiClient.post<Map<String, dynamic>>(
        path,
        data: formData,
      );
      return response;
    }, errorMessage: 'POST multipart request failed for $path');
  }

  /// PUT request helper
  Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return executeCall(() async {
      final response = await apiClient.put<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response;
    }, errorMessage: 'PUT request failed for $path');
  }

  /// DELETE request helper
  Future<Map<String, dynamic>?> delete(
    String path, {
    Map<String, dynamic>? data,
  }) async {
    return executeCall(() async {
      final response = await apiClient.delete<Map<String, dynamic>>(
        path,
        data: data,
      );
      return response;
    }, errorMessage: 'DELETE request failed for $path');
  }

  /// Handle Dio exceptions
  Exception _handleDioException(DioException e, String errorMessage) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkException('Request timeout');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode ?? 500;
        final message = e.response?.data['message'] ?? errorMessage;
        return ServerException(message, statusCode);
      case DioExceptionType.connectionError:
        return NetworkException('Connection error');
      case DioExceptionType.cancel:
        return NetworkException('Request cancelled');
      default:
        return ServerException(errorMessage, 500);
    }
  }
}

/// Base class for local data sources
/// Handles common cache operations and exception management
abstract class BaseLocalDataSource {
  /// Execute local operation with error handling
  Future<T> executeCall<T>(
    Future<T> Function() call, {
    String errorMessage = 'Local operation failed',
  }) async {
    try {
      return await call();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('$errorMessage: ${e.toString()}');
    }
  }

  /// Execute synchronous operation with error handling
  T executeSync<T>(
    T Function() call, {
    String errorMessage = 'Local operation failed',
  }) {
    try {
      return call();
    } on CacheException {
      rethrow;
    } catch (e) {
      throw CacheException('$errorMessage: ${e.toString()}');
    }
  }
}
