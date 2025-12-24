import 'package:logger/logger.dart';

class AppLogger {
  final Logger _logger;

  AppLogger()
    : _logger = Logger(
        printer: PrettyPrinter(
          methodCount: 0,
          errorMethodCount: 5,
          lineLength: 50,
          colors: true,
          printEmojis: true,
          dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
        ),
      );

  void debug(String message) {
    _logger.d(message);
  }

  void info(String message) {
    _logger.i(message);
  }

  void warning(String message) {
    _logger.w(message);
  }

  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  void verbose(String message) {
    _logger.t(message);
  }
}
