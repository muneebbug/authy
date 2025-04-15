import 'package:logger/logger.dart';

/// A centralized logging utility for the application
class LoggerUtil {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 0,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      printTime: true,
    ),
    level: Level.warning, // Set to warning by default for production
  );

  /// Enable debug logs (for development only)
  static void enableDebugLogs() {
    Logger.level = Level.debug;
  }

  /// Log information messages
  static void info(String message) {
    _logger.i(message);
  }

  /// Log debug messages
  static void debug(String message) {
    _logger.d(message);
  }

  /// Log warning messages
  static void warning(String message) {
    _logger.w(message);
  }

  /// Log error messages with optional stack trace
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// Log verbose messages (detailed debugging)
  static void verbose(String message) {
    _logger.v(message);
  }

  /// Log section dividers
  static void section(String sectionTitle) {
    _logger.i('========== $sectionTitle ==========');
  }
}
