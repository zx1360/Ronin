import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

/// 前台服务保活
class LatheForegroundService {
  LatheForegroundService._();
  static final LatheForegroundService instance = LatheForegroundService._();

  bool _isInitialized = false;
  bool _isRunning = false;

  /// 初始化前台服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'lathe_foreground_channel',
        channelName: '倒计时服务',
        channelDescription: '倒计时器后台运行服务',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(1000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _isInitialized = true;
  }

  /// 请求忽略电池优化权限
  Future<bool> requestIgnoreBatteryOptimizations() async {
    final status = await Permission.ignoreBatteryOptimizations.request();
    return status.isGranted;
  }

  /// 启动前台服务
  Future<bool> startService() async {
    if (_isRunning) return true;
    if (!_isInitialized) await initialize();

    // 请求忽略电池优化
    await requestIgnoreBatteryOptimizations();

    final result = await FlutterForegroundTask.startService(
      notificationTitle: '倒计时运行中',
      notificationText: '正在计时...',
      notificationIcon: null,
      callback: null,
    );

    _isRunning = result is ServiceRequestSuccess;
    return _isRunning;
  }

  /// 停止前台服务
  Future<bool> stopService() async {
    if (!_isRunning) return true;

    final result = await FlutterForegroundTask.stopService();
    final success = result is ServiceRequestSuccess;
    _isRunning = !success;
    return success;
  }

  /// 更新前台服务通知内容
  Future<void> updateNotification({
    required String title,
    required String text,
  }) async {
    if (!_isRunning) return;
    await FlutterForegroundTask.updateService(
      notificationTitle: title,
      notificationText: text,
    );
  }

  /// 是否正在运行
  bool get isRunning => _isRunning;
}
