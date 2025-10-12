import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:torrid/core/services/storage/user_pref_provider/app_setting.dart';

class PrefsService {
  // 饿汉式单例
  static final PrefsService _instance = PrefsService._();
  PrefsService._();
  // 静态唯一实例
  factory PrefsService() => _instance;

  // 初始化prefs值
  Future<void> initPrefs() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 确保偏好设置preferences有值.
  Future<void> ensureSettingsHasValue() async {
    if (!_prefs.containsKey("preferences") ||
        _prefs.getString("preferences") == "") {
      final settings = AppSettings.defaultValue();
      await _prefs.setString("preferences", jsonEncode(settings.toJson()));
    }
  }

  // 由此管理的唯一对象
  late SharedPreferences _prefs;
  SharedPreferences get prefs {
    return _prefs;
  }
}
