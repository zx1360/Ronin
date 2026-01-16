import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';

/// 倒计时通知服务
class LatheNotificationService {
  LatheNotificationService._();
  static final LatheNotificationService instance = LatheNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // Android初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS初始化设置
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    _isInitialized = true;
  }

  /// 请求通知权限
  Future<bool> requestPermission() async {
    final status = await Permission.notification.request();
    return status.isGranted;
  }

  /// 检查通知权限
  Future<bool> checkPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// 显示倒计时完成通知
  Future<void> showTimerCompletedNotification(String timerName) async {
    if (!_isInitialized) await initialize();

    // 播放消息提示音（类似微信/QQ消息提示）
    await FlutterRingtonePlayer().playNotification(
      looping: false,
      volume: 0.8,
    );

    // 显示通知（消息类型，启用横幅弹出）
    const androidDetails = AndroidNotificationDetails(
      'lathe_timer_channel',
      '倒计时提醒',
      channelDescription: '倒计时器完成提醒通知',
      importance: Importance.max,  // 最高优先级，确保横幅弹出
      priority: Priority.max,      // 最高优先级
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.message,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      ticker: '倒计时完成',  // 状态栏提示文字
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,  // iOS横幅
      presentList: true,
      interruptionLevel: InterruptionLevel.active,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;
    
    await _notificationsPlugin.show(
      notificationId,
      '⏰ 倒计时完成',
      '"$timerName" 已归零',
      notificationDetails,
    );
  }

  /// 通知响应回调
  void _onNotificationResponse(NotificationResponse response) {
    // 可以在这里处理用户点击通知的行为
  }

  /// 取消所有通知
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// 取消指定通知
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }
}
