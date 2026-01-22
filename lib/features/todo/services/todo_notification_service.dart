/// Todo 通知服务
/// 
/// 提供待办事项到期提醒功能：
/// - 检查到期任务并发送系统通知
/// - 支持自定义提醒时间
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

import 'package:torrid/features/todo/models/todo_task.dart' hide Priority;

/// Todo 通知服务单例
class TodoNotificationService {
  TodoNotificationService._();
  static final TodoNotificationService instance = TodoNotificationService._();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;
  
  /// 通知渠道ID
  static const String _channelId = 'todo_due_reminder';
  static const String _channelName = '待办提醒';
  static const String _channelDescription = '待办事项到期提醒通知';

  // 通知颜色常量
  static const Color _dueColor = Color(0xFF2196F3);
  static const Color _reminderColor = Color(0xFF4CAF50);
  static const Color _overdueColor = Color(0xFFE91E63);

  /// 初始化通知服务
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 初始化时区
    tzdata.initializeTimeZones();
    final String currentTimeZone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(currentTimeZone));

    // Android 初始化设置
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // iOS 初始化设置
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

  /// 通知点击响应
  void _onNotificationResponse(NotificationResponse response) {
    // 可以在这里处理通知点击事件，比如跳转到对应任务
    // 暂时不做处理
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

  /// 为任务安排到期提醒通知
  /// 
  /// [task] 要设置提醒的任务
  Future<void> scheduleTaskDueNotification(TodoTask task) async {
    if (!_isInitialized) await initialize();
    if (task.dueDate == null || task.isDone) return;

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    // 取消之前的通知（如果有）
    await cancelTaskNotification(task.id);

    // 设置提醒时间：到期日当天上午 9:00
    final dueDate = task.dueDate!;
    final notifyTime = DateTime(dueDate.year, dueDate.month, dueDate.day, 9, 0);
    
    // 如果提醒时间已过，则不安排通知
    if (notifyTime.isBefore(DateTime.now())) return;

    final tzNotifyTime = tz.TZDateTime.from(notifyTime, tz.local);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      colorized: true,
      color: _dueColor,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 使用任务ID的哈希作为通知ID
    final notificationId = task.id.hashCode.abs() % 100000;

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      '待办提醒',
      '「${task.title}」今天到期',
      tzNotifyTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 为任务安排自定义提醒通知
  Future<void> scheduleTaskReminderNotification(TodoTask task) async {
    if (!_isInitialized) await initialize();
    if (task.reminder == null || task.isDone) return;

    // 检查权限
    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    // 如果提醒时间已过，则不安排通知
    if (task.reminder!.isBefore(DateTime.now())) return;

    final tzReminderTime = tz.TZDateTime.from(task.reminder!, tz.local);

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      colorized: true,
      color: _reminderColor,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 使用 "reminder_" + 任务ID的哈希作为通知ID，避免与到期通知冲突
    final notificationId = ('reminder_${task.id}').hashCode.abs() % 100000;

    await _notificationsPlugin.zonedSchedule(
      notificationId,
      '任务提醒',
      task.title,
      tzReminderTime,
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// 取消任务的到期通知
  Future<void> cancelTaskNotification(String taskId) async {
    final notificationId = taskId.hashCode.abs() % 100000;
    await _notificationsPlugin.cancel(notificationId);
  }

  /// 取消任务的提醒通知
  Future<void> cancelTaskReminderNotification(String taskId) async {
    final notificationId = ('reminder_$taskId').hashCode.abs() % 100000;
    await _notificationsPlugin.cancel(notificationId);
  }

  /// 取消所有待办通知
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }

  /// 立即显示到期任务通知（用于检查已过期的任务）
  Future<void> showOverdueNotification(TodoTask task) async {
    if (!_isInitialized) await initialize();
    if (task.isDone) return;

    final hasPermission = await checkPermission();
    if (!hasPermission) return;

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
      autoCancel: true,
      colorized: true,
      color: _overdueColor,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      presentBanner: true,
      presentList: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final notificationId = DateTime.now().millisecondsSinceEpoch % 100000;

    await _notificationsPlugin.show(
      notificationId,
      '任务已过期',
      '「${task.title}」已过期，请尽快处理',
      notificationDetails,
    );
  }
}
