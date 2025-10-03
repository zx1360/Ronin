import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  static final PrefsService _instance = PrefsService._internal();
  PrefsService._internal();
  // 静态唯一实例
  factory PrefsService() => _instance;
  // 由此管理的唯一对象
  static SharedPreferences? _prefs;

  // 确保其初始化, 且仅初始化一次.
  static Future<SharedPreferences> get prefs async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }
}
