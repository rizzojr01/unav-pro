import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import '../error/exceptions.dart';
import 'api_timer_tracker.dart';
import '../services/server_config_service.dart';
import '../utils/logger.dart';

class ApiClient {
  final Dio _dio;
  final AppLogger _logger;
  final ServerConfigService _serverConfig;

  ApiClient({
    required ServerConfigService serverConfig,
    required AppLogger logger,
  }) : _logger = logger,
      _serverConfig = serverConfig,
      _dio = Dio(
        BaseOptions(
          baseUrl: serverConfig.currentUrl,
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

  /// Always target the currently selected server before issuing a request so
  /// runtime switches between local and Koyeb take effect immediately.
  void _useActiveBaseUrl() {
    _dio.options.baseUrl = _serverConfig.currentUrl;
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

  /// Total window for retrying failed connects. The OS aborts a single TCP
  /// connect attempt after ~75s (errno 60) no matter what connectTimeout
  /// says, so "wait 5 minutes" is only achievable by retrying attempts
  /// until the window closes — e.g. while the server cold-starts.
  static const _connectRetryWindow = Duration(minutes: 5);
  static const _connectRetryDelay = Duration(seconds: 3);

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          _logger.info('Request: ${options.method} ${options.path}');
          // ??= so retries keep the original timer and window anchor.
          options.extra['firstAttemptMs'] ??=
              DateTime.now().millisecondsSinceEpoch;
          options.extra['timerId'] ??= ApiTimerTracker.instance
              .begin('${options.method} ${options.path}');
          return handler.next(options);
        },
        onResponse: (response, handler) {
          _logger.info(
            'Response: ${response.statusCode} ${response.requestOptions.path}',
          );
          final id = response.requestOptions.extra['timerId'];
          if (id is int) ApiTimerTracker.instance.end(id);
          return handler.next(response);
        },
        onError: (error, handler) async {
          final opts = error.requestOptions;
          final couldNotConnect =
              error.type == DioExceptionType.connectionTimeout ||
                  error.type == DioExceptionType.connectionError ||
                  error.error is SocketException;
          final firstAttemptMs = opts.extra['firstAttemptMs'] as int?;
          final withinWindow = firstAttemptMs != null &&
              DateTime.now().millisecondsSinceEpoch - firstAttemptMs <
                  _connectRetryWindow.inMilliseconds;
          if (couldNotConnect && withinWindow) {
            _logger.info(
              'Connect failed for ${opts.path} — retrying '
              '(server may be cold-starting)',
            );
            await Future<void>.delayed(_connectRetryDelay);
            try {
              final response = await _dio.fetch<dynamic>(opts);
              return handler.resolve(response);
            } on DioException catch (e) {
              return handler.next(e);
            }
          }
          _logger.error('Error: ${error.message}', error: error);
          final id = opts.extra['timerId'];
          if (id is int) ApiTimerTracker.instance.end(id, failed: true);
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
    _useActiveBaseUrl();
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
    _useActiveBaseUrl();
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
    _useActiveBaseUrl();
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
    _useActiveBaseUrl();
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
          errorMessage =
              friendlyServerMessage(data, error.response?.statusCode);
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
