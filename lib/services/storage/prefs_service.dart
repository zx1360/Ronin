import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrid/providers/shared_preferences/app_settings_provider.dart';

class PrefsService {
  // 饿汉式单例
  static final PrefsService _instance = PrefsService._();
  PrefsService._();
  // 静态唯一实例
  factory PrefsService() => _instance;

  // 由此管理的唯一对象
  late SharedPreferences _prefs;
  SharedPreferences get prefs {
    return _prefs;
  }

  // 初始化prefs值
  Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
    await _ensureSettingsHasValue();
  }

  // 确保偏好设置preferences有值.
  Future<void> _ensureSettingsHasValue() async {
    if (!_prefs.containsKey("preferences") ||
        _prefs.getString("preferences") == "") {
      final settings = AppSettings.defaultValue();
      await _prefs.setString("preferences", jsonEncode(settings.toJson()));
    }
  }
}
