import 'package:shared_preferences/shared_preferences.dart';

class PrefsService {
  // 饿汉式单例
  static final PrefsService _instance = PrefsService._();
  PrefsService._();
  // 静态唯一实例
  factory PrefsService() => _instance;

  // 初始化prefs值
  Future<void> initPrefs()async{
    _prefs = await SharedPreferences.getInstance();
  }
  // 由此管理的唯一对象
  static late SharedPreferences _prefs;

  // 确保其初始化, 且仅初始化一次.
  static SharedPreferences get prefs{
    return _prefs;
  }
}
