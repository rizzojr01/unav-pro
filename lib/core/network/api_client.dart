import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../error/exceptions.dart';
import '../utils/logger.dart';

class ApiClient {
  final Dio _dio;
  final AppLogger _logger;

  ApiClient({required String baseUrl, required AppLogger logger})
    : _logger = logger,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          connectTimeout: const Duration(minutes: 5),
          receiveTimeout: const Duration(minutes: 5),
          sendTimeout: const Duration(minutes: 5),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
          },
        ),
      ) {
    _setupInterceptors();
    _setupCertificateBypass();
  }

  void _setupCertificateBypass() {
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback =
            (X509Certificate cert, String host, int port) => true;
        return client;
      },
    );
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.info('Request: ${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.info(
            'Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          return handler.next(response);
        },
        onError: (error, handler) {
          _logger.error('Error: ${error.message}', error: error);
          return handler.next(error);
        },
      ),
    );
  }

  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  Future<T> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data as T;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  AppException _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkException('Connection timeout');
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        String errorMessage = 'Server error';

        if (data is Map<String, dynamic>) {
          errorMessage =
              data['message'] ??
              data['error'] ??
              data['details'] ??
              'Server error';
        } else if (data is String) {
          errorMessage = data;
        }

        return ServerException(errorMessage, error.response?.statusCode);
      case DioExceptionType.cancel:
        return const NetworkException('Request cancelled');
      case DioExceptionType.connectionError:
        return const NetworkException('No internet connection');
      default:
        return NetworkException('Unexpected error: ${error.message}');
    }
  }
}
