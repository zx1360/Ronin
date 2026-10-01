import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';

// 全局日志单例：统一转发到 logging 包，再由 debugPrint 输出。
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  factory AppLogger() => _instance;

  final Logger _logger = Logger("App");

  AppLogger._internal() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      debugPrint('${record.time} [${record.level.name}] ${record.message}');
    });
  }

  void debug(String message) => _logger.fine(message);
  void info(String message) => _logger.info(message);
  void warning(String message) => _logger.warning(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.severe(message, error, stackTrace);
}
