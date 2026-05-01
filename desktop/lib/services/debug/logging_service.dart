import 'package:logging/logging.dart';

// 单例模式, 日志输出.
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  // 工厂构造函数, 外部调用AppLogger()返回同一实例.
  factory AppLogger() => _instance;

  final Logger _logger = Logger("App");

  AppLogger._internal() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) {
      // 监听到日志消息后的操作 TODO:之后写入日志文件.
      print('${record.time} [${record.level.name}] ${record.message}');
      // if(record.level>=Level.SEVERE) {
      //   // 上报严重错误
      // }
    });
  }

  // 不同级别的日志记录
  void debug(String message) => _logger.fine(message);
  void info(String message) => _logger.info(message);
  void warning(String message) => _logger.warning(message);
  void error(String message, [Object? error, StackTrace? stackTrace]) =>
      _logger.fine(message, error, stackTrace);

  // 设置日志级别
  void setLevel(Level level){
    Logger.root.level = level;
  }
}

// 全局函数, 简化调用
void logDebug(String message)=>AppLogger().debug(message);
void logInfo(String message)=>AppLogger().info(message);
void logWarning(String message)=>AppLogger().warning(message);
void logError(String message)=>AppLogger().error(message);
